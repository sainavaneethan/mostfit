class PaymentTransactions < Application

  @@biz_location_ids = []

  def index
    if params[:lending_ids]
      @payment_transactions = PaymentTransaction.all(:on_product_id => params[:lending_ids], :on_product_type => :lending)
    elsif params[:payment_ids]
      @payment_transactions = PaymentTransaction.all(:id => params[:payment_ids])
    else
      @payment_transactions = PaymentTransaction.all
    end
    display @payment_transactions
  end

  def new
    @payment_transaction = PaymentTransaction.new
    display @payment_transaction
  end

  def payment_form_for_lending
    @lending = Lending.get params[:lending_id]
    @payment_transaction = PaymentTransaction.new
    render :template => 'payment_transactions/payment_form_for_lending', :layout => layout?
  end

  def weeksheet_payments
    @date                = params[:date].blank? ? session[:effective_date] : Date.parse(params[:date])
    @biz_location        = BizLocation.get params[:biz_location_id]
    @parent_biz_location = LocationLink.get_parent(@biz_location, @date)
    @user                = session.user
    @staff_member        = @user.staff_member
    @weeksheet           = CollectionsFacade.new(session.user.id).get_collection_sheet(@biz_location.id, @date)
    partial 'payment_transactions/weeksheet_payments', :layout => layout?
  end

  def payment_by_staff_member_for_location
    @weeksheets      = []
    @message         = {}
    @message[:error] = 'Staff Member cannot be blank' if params[:staff_member_id].blank?
    @message[:error] = 'Please Select Location For Payment' if @@biz_location_ids.blank? && params[:biz_location_ids].blank?
    if @message[:error].blank?
      @date             = params[:date].blank? ? session[:effective_date] : Date.parse(params[:date])
      @staff_member     = StaffMember.get(params[:staff_member_id])
      @user             = session.user
      @biz_location_ids = params[:biz_location_ids].blank? ? @@biz_location_ids : params[:biz_location_ids]
      @biz_location_ids.each{|location_id| @weeksheets << CollectionsFacade.new(session.user.id).get_collection_sheet(location_id, @date)}
    end
    if @message[:error].blank?
      display @weeksheets.flatten!
    else
      redirect request.referer, :message => @message
    end
  end

  def payment_by_staff_member
    @weeksheets      = []
    @message         = {}
    @message[:error] = 'Staff Member cannot be blank' if params[:staff_member_id].blank?
    if @message[:error].blank?
      @date                = params[:date].blank? ? session[:effective_date] : Date.parse(params[:date])
      @child_biz_location  = BizLocation.get(params[:child_location_id])
      @parent_biz_location = BizLocation.get(params[:parent_location_id])
      @staff_member        = StaffMember.get(params[:staff_member_id])
      @user                = session.user
      @weeksheets          = collections_facade.get_collection_sheet_for_staff(@staff_member.id, @date)
    end
    display @weeksheets.flatten!
  end

  def create_group_payments
    
    # INITIALIZING VARIABLES USED THROUGHTOUT
    @message              = {:error => [], :notice => []}
    @payment_transactions = []
    @client_attendance    = {}
    
    # GATE-KEEPING
    currency     = 'INR'
    receipt      = 'receipt'
    product_type = 'lending'
    cp_type      = 'client'
    recorded_by  = session.user.id
    operation    = params[:operation]
    effective_on = params[:payment_transactions][:on_date]
    payments     = params[:payment_transactions][:payments]
    performed_by = params[:payment_transactions][:performed_by]


    # VALIDATIONS
    @message[:error] << "Date cannot be blank" if effective_on.blank?
    @message[:error] << "Please Select Operation Type(Payment/Attendance/Both)" if operation.blank?
    @message[:error] << "Performed by must not be blank" if performed_by.blank?
    @message[:error] << "Please Select Check box For Payment/Attendance" if payments.values.select{|f| f[:payment]}.blank?
    @message[:error] << "Please Enter Amount Greater Than ZERO" if ['payment','payment_and_client_attendance'].include?(operation) && !payments.values.select{|f| f[:amount].to_f <= 0}.blank?
    
    # OPERATIONS PERFORMED
    if @message[:error].blank?
      begin
        payments.each do |key, payment_value|
          unless payment_value[:payment].blank?

            payment_towards = Constants::Transaction::PAYMENT_TOWARDS_LOAN_REPAYMENT
            money_amount    = MoneyManager.get_money_instance(payment_value[:amount].to_f)
            cp_id           = payment_value[:counterparty_id]
            product_id      = payment_value[:product_id]
            performed_at    = payment_value[:performed_at]
            accounted_at    = payment_value[:accounted_at]
            if ['client_attendance','payment_and_client_attendance'].include?(operation)
              @client_attendance[cp_id]                     = {}
              @client_attendance[cp_id][:counterparty_type] = 'client'
              @client_attendance[cp_id][:counterparty_id]   = cp_id
              @client_attendance[cp_id][:on_date]           = effective_on
              @client_attendance[cp_id][:at_location]       = performed_at
              @client_attendance[cp_id][:performed_by]      = performed_by
              @client_attendance[cp_id][:recorded_by]       = recorded_by
              @client_attendance[cp_id][:attendance]        = payment_value[:client_attendance]
            end
            if(money_amount.amount > 0 && ['payment','payment_and_client_attendance'].include?(operation))
              payment_transaction     = PaymentTransaction.new(:amount => money_amount.amount, :currency => currency, :effective_on => effective_on,
                :on_product_type      => product_type, :on_product_id  => product_id,
                :performed_at         => performed_at, :accounted_at   => accounted_at,
                :performed_by         => performed_by, :recorded_by    => recorded_by,
                :by_counterparty_type => cp_type, :by_counterparty_id  => cp_id,
                :receipt_type         => receipt, :payment_towards     => payment_towards)
              if payment_transaction.valid?
                if payment_facade.is_loan_payment_permitted?(payment_transaction)
                  @payment_transactions << payment_transaction
                else
                  @message[:error] << "#{@message[:error]}  #{product_type}(#{product_id}) {#{payment_transaction.errors.collect{|error| error}.flatten.join(', ')}}"
                end
              end
            end
          end
        end
        if @message[:error].blank?
          @payment_transactions.each do |pt|
            begin
              money_amount = pt.to_money[:amount]
              payment_facade.record_payment(money_amount, pt.receipt_type, pt.payment_towards, pt.on_product_type, pt.on_product_id, pt.by_counterparty_type, pt.by_counterparty_id, pt.performed_at, pt.accounted_at, pt.performed_by, pt.effective_on, Constants::Transaction::LOAN_REPAYMENT)
              @message[:notice] << "#{operation.humanize} successfully created"
            rescue => ex
              @message[:error] << "An error has occured: #{ex.message}"
            end
          end
          
          if ['client_attendance','payment_and_client_attendance'].include?(operation)
            AttendanceRecord.save_and_update(@client_attendance) if @client_attendance.size > 0
            @message[:notice] << "#{operation.humanize} successfully created" if @message[:notice].blank?
          end
        end
      rescue => ex
        @message[:error] << "An error has occured: #{ex.message}"
      end
    end
    @message[:error].blank? ? @message.delete(:error) : @message.delete(:notice)
    @staff_member_id     = params[:staff_member_id]
    @parent_location_id  = params[:parent_location_id]
    @child_location_id   = params[:child_location_id]
    @@biz_location_ids = payments.values.collect{|s| s[:performed_at]}.compact.uniq
    add_url = "?staff_member_id=#{params[:staff_member_id]}&parent_location_id=#{params[:parent_location_id]}&child_location_id=#{params[:child_location_id]}"
    # REDIRECT/RENDER
    redirect request.referer+add_url, :message => @message
  end
  
end