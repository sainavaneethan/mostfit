class PaymentTransactions < Application

  @@biz_location_ids = []

  def index
    if params[:staff_member_id].blank?
      redirect request.referer
    else
      redirect resource(:payment_transactions, :payment_by_staff_member, params.except(:action, :controller))
    end
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
    page             = params[:page].blank? ? 1 : params[:page]
    limit            = 3
    @message[:error] = 'Staff Member cannot be blank' if params[:staff_member_id].blank?
    if @message[:error].blank?
      @date                = params[:date].blank? ? get_effective_date : Date.parse(params[:date])
      @child_biz_location  = BizLocation.get(params[:child_location_id])
      @parent_biz_location = BizLocation.get(params[:parent_location_id])
      @staff_member        = StaffMember.get(params[:staff_member_id])
      @user                = session.user
      @biz_locations, @weeksheets = collections_facade.get_all_collection_sheet_for_staff(@staff_member.id, @date, @parent_biz_location, page, limit)
    end
    @weeksheets = @weeksheets.class == Array ? @weeksheets : [@weeksheets]
    display @weeksheets
  end

  def create_group_payments
    
    # INITIALIZING VARIABLES USED THROUGHTOUT
    @message              = {:error => [], :notice => [],:weeksheet_error => ''}
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
    @message[:error] << "Please Select Check box For #{operation.humanize}" if payments.values.select{|f| f[:payment]}.blank?
    @message[:error] << "Please Enter Amount Greater Than ZERO" if ['payment','payment_and_client_attendance'].include?(operation) && !payments.values.select{|f| f[:payment] && f[:amount].to_f <= 0}.blank?
    
    # OPERATIONS PERFORMED
    if @message[:error].blank?
      begin
        payments.values.select{|d| d[:payment]}.each do |payment_value|
          unless payment_value[:payment].blank?

            lending = Lending.get(payment_value[:product_id])
            if lending.is_written_off?
              payment_towards  = Constants::Transaction::PAYMENT_TOWARDS_LOAN_RECOVERY
            else
              payment_towards  = Constants::Transaction::PAYMENT_TOWARDS_LOAN_REPAYMENT
            end
            money_amount    = MoneyManager.get_money_instance(payment_value[:amount].to_f)
            cp_id           = payment_value[:counterparty_id]
            product_id      = payment_value[:product_id]
            performed_at    = payment_value[:performed_at]
            accounted_at    = payment_value[:accounted_at]
            receipt_no      = payment_value[:receipt_no].blank? ? nil : payment_value[:receipt_no]
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
                :on_product_type      => product_type, :on_product_id  => product_id, :receipt_no => receipt_no,
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
          payments  = {}
          @payment_transactions.each do |pt|
            begin
              if pt.save
                payments[pt] = payment_facade.record_payment_allocation(pt)
                @message[:notice] << "#{operation.humanize} successfully created"
              else
                @message[:error] << "An error has occured: #{pt.errors.first.join(',')}"
              end
            rescue => ex
              @message[:error] << "An error has occured: #{ex.message}"
            end
          end
          payments.each do |payment, allocation|
            payment_facade.record_payment_accounting(payment, allocation)
          end

          if ['client_attendance','payment_and_client_attendance'].include?(operation)
            Thread.new{
              AttendanceRecord.save_and_update(@client_attendance) if @client_attendance.size > 0
            }
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
    params[:page]       = params[:page].blank? ? 1 : params[:page]
    page                 = @message[:error].blank? ? params[:page].to_i+1 : params[:page]
    @message[:notice].uniq! unless @message[:notice].blank?
    @message[:error].uniq! unless @message[:error].blank?
    @@biz_location_ids = payments.values.collect{|s| s[:performed_at]}.compact.uniq
    # REDIRECT/RENDER
    redirect resource(:payment_transactions, :payment_by_staff_member, :date => effective_on, :staff_member_id => params[:staff_member_id], :parent_location_id => params[:parent_location_id], :child_location_id => params[:child_location_id], :page => page, :save_payment => true), :message => @message
  end

  def payment_transactions_on_date
    @branch_id = params[:parent_location_id]
    @center_id = params[:child_location_id]
    @on_date   = params[:date]
    @error = []
    @error << "Please Select Branch" if @branch_id.blank?
    @error << "Please Select Center" if @center_id.blank?
    @error << "Date cannot be blank" if @on_date.blank?
    @payment_transactions = []
    if @error.blank?
      @payment_transactions = PaymentTransaction.all(:accounted_at => @branch_id, :performed_at => @center_id, :effective_on => @on_date, :payment_towards => Constants::Transaction::REVERT_PAYMENT_TOWARDS)
    end
    display @payment_transactions, :message => {:error => @error}
  end

  def destroy_payment_transactions_on_date
    @branch_id = params[:parent_location_id]
    @center_id = params[:child_location_id]
    @on_date   = params[:date]
    @error = []
    @error << "Please Select Branch" if @branch_id.blank?
    @error << "Please Select Center" if @center_id.blank?
    @error << "Date cannot be blank" if @on_date.blank?
    @payment_transactions = []
    if @error.blank?
      @payment_transactions = PaymentTransaction.with_deleted{PaymentTransaction.all(:deleted_at.not => nil, :accounted_at => @branch_id, :performed_at => @center_id, :effective_on => @on_date)}
    end
    render :template => 'payment_transactions/destroy_payment_transactions_on_date', :layout => layout?
  end

  def destroy_payment_transactions
    @error = []
    payments = params[:payment_trasactions]
    @error << "Please Select Check box" if payments.blank?
    if @error.blank?
      payments.each do |payment_id|
        payment = PaymentTransaction.get payment_id
        payment.delete_payment_transaction
      end
    end

    if @error.blank?
      redirect request.referer, :message => {:notice => "Payment Transaction successfully deleted"}
    else
      redirect request.referer, :message => {:error => @error}
    end
  end

end