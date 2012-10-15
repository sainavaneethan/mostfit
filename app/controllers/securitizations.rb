class Securitizations < Application

  require "tempfile"

  def index
    @securitizations=Securitization.all
    display @securitizations
  end
  
  def show
    @securitization = Securitization.get(params[:id])
    raise NotFound unless @securitization
    @date = params[:secu_date].blank? ? get_effective_date : Date.parse(params[:secu_date])
    @lendings = loan_assignment_facade.get_loans_assigned(@securitization,@date) 

    do_calculations

    render :template => 'securitizations/show', :layout => layout?
  end

  def new
    @securitization=Securitization.new
    display @securitization
  end
  
  def create(securitization)
    @securitization = Securitization.new(securitization)
    @errors = []
    @errors << "Securitization name must not be blank " if params[:securitization][:name].blank?
    @errors << "Effective date must not be blank " if params[:securitization][:effective_on].blank?
    if @errors.blank?
      if(Securitization.all(:name => @securitization.name).count==0)
        if @securitization.save!
          redirect("/securitizations", :message => {:notice => "Securitization '#{@securitization.name}' (Id:#{@securitization.id}) successfully created"})
        else
          message[:error] = "Securitization failed to be created"
          render :new  # error messages will show
        end
      else
        message[:error] = "Securitization with same name already exists !"
        render :new  # error messages will show
      end
    else
      message[:error] = @errors.to_s
      render :new
    end
  end

  def loans_for_securitization_on_date
    @securitization = Securitization.get(params[:id])
    raise NotFound unless @securitization
    @date = params[:secu_date].blank? ? get_effective_date : Date.parse(params[:secu_date])
    @lendings = loan_assignment_facade.get_loans_assigned(@securitization,@date) 

    do_calculations

    render :template => 'securitizations/show', :layout => layout?
  end

  def do_calculations
    @errors = []
    money_hash_list = []
    begin 
      @lendings.each do |lending|
        lds = LoanDueStatus.most_recent_status_record_on_date(lending, @date)
        money_hash_list << lds.to_money
      end 
        
      in_currency = MoneyManager.get_default_currency
      @total_money = Money.add_money_hash_values(in_currency, *money_hash_list)
    rescue => ex
      @errors << ex.message
    end
  end

  def eligible_loans_for_loan_assignments
    @errors = []
    branch_id = params[:parent_location_id]
    center_id = params[:child_location_id]
    unless params[:flag] == 'true'
      @errors << "No branch selected " if branch_id.blank?
      @errors << "No center selected " if center_id.blank?
    end
    @lendings = loan_facade.loans_eligible_for_sec_or_encum(params[:child_location_id]) if @errors.blank?
    render :eligible_loans_for_loan_assignments
  end

  def loan_assignments
    @loan_assignments = LoanAssignment.all
    render
  end

  def upload_loan_assignment_file
    # INITIALIZATIONS
    @errors = []
    @loan_assignments = LoanAssignment.all

    # VALIDATIONS
    @errors << "Please select file" if params[:file].blank?
    @errors << "Invalid file selection (Accepts .xls extension file only)" if params[:file][:content_type] && params[:file][:content_type] != "application/vnd.ms-excel"

    # OPERATION PERFORMED
    if @errors.blank?
      filename = params[:file][:filename]
      xls_folder = File.join("#{Merb.root}/public/uploads", "loan_assignments", "uploaded_xls")
      FileUtils.mkdir_p(xls_folder)
      xls_filepath = File.join(xls_folder, filename)
      FileUtils.mv(params[:file][:tempfile].path, xls_filepath)

      csv_folder = File.join("#{Merb.root}/public/uploads", "loan_assignments", "converted_csv")
      FileUtils.mkdir_p(csv_folder)
      User.convert_xls_to_csv(xls_filepath, "#{csv_folder}/loan_assignment")
    end

    # RENDER/RE-DIRECT
    render :loan_assignments
  end

  def download_xls_file_format
    send_file('public/loan_assignment_file_format.xls', :filename => ('public/loan_assignment_file_format.xls'.split("/")[-1].chomp))
  end

end