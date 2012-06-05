class Lendings < Application

  def index

  end

  def new
    @lending_product = LendingProduct.get params[:lending_product_id]
    @client = Client.get params[:client_id]
    @counterparty_ids = ClientAdministration.all.aggregate(:counterparty_id)
    @clients = Client.all(:id => @counterparty_ids)
    @lending = @lending_product.lendings.new
    display @lending_product
  end

  def create
    #INITIALIZING VARIABLES USED THOURGHTOUT
    @message = {}

    #GET-KEEPING
    lending_product_id            = params[:lending_product_id]
    lan_id                        = params[:lending][:lan]
    applied_date                  = params[:lending][:applied_on_date]
    applied_by_staff              = params[:lending][:applied_by_staff]
    schedule_disbursal_date       = params[:lending][:scheduled_disbursal_date]
    schedule_first_repayment_date = params[:lending][:scheduled_first_repayment_date]
    client_id                     = params[:lending][:for_borrower_id]
    recorded_by_user              = session.user.id
    @client                       = Client.get client_id unless client_id.blank?
    @lending_product              = LendingProduct.get lending_product_id unless lending_product_id.blank?

    # VALIDATIONS
    @message[:error] = "Loan Id cannot blank" if lan_id.blank?
    @message[:error] = "Applied Date cannot blank" if applied_date.blank?
    @message[:error] = "Please select staff" if applied_by_staff.blank?
    @message[:error] = "Schedule Disbursal Date cannot blank" if schedule_disbursal_date.blank?
    @message[:error] = "Schedule First Repayment Date cannot blank" if schedule_first_repayment_date.blank?
    @lending = @lending_product.lendings.new(params[:lending])

    # PERFORM OPERATION
    if @message[:error].blank?
      begin
        @client_admin = ClientAdministration.first :counterparty_type => 'client', :counterparty_id => @client.id
        money_amount = MoneyManager.get_money_instance_least_terms(@lending_product.amount.to_i)
        lending = Lending.create_new_loan(money_amount, @lending_product.repayment_frequency.to_s, @lending_product.tenure, @lending_product,
          client_id, @client_admin.administered_at, @client_admin.registered_at, applied_date, schedule_disbursal_date,
          schedule_first_repayment_date, applied_by_staff, recorded_by_user, lan_id)

        if lending.new?
          @message[:error] = lending.error.first.join(", ")
        else
          @message[:notice] = "Lending created successfully"
        end
      rescue => ex
        @message = {:error => "An error has occured: #{ex.message}"}
      end
    end

    #REDIRECTION/RENDER
    if @message[:error].blank?
      redirect resource(:lending_products), :message => @message
    else
      render :new
    end
    
  end


  def edit

  end

  def update
    
  end
end