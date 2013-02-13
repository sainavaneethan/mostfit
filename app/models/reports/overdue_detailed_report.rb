class OverdueDetailedReport < Report
  attr_accessor :biz_location_branch_id, :date, :page, :file_format

  def initialize(params, dates, user)
    @date = dates[:date] || Date.today
    @name = "Overdue Detailed Report"
    @user = user
    location_facade = get_location_facade(@user)
    all_branch_ids = location_facade.all_nominal_branches.collect {|branch| branch.id}
    @biz_location_branch = (params and params[:biz_location_branch_id] and (not (params[:biz_location_branch_id].empty?))) ? params[:biz_location_branch_id] : all_branch_ids
    @page = params.blank? || params[:page].blank? ? 1 :params[:page]
    @limit = 100
    get_parameters(params, user)
  end

  def name
    "Overdue Detailed Report for #{@date}"
  end

  def self.name
    "Overdue Detailed Report"
  end
  
  def get_reporting_facade(user)
    @reporting_facade ||= FacadeFactory.instance.get_instance(FacadeFactory::REPORTING_FACADE, user)
  end

  def get_location_facade(user)
    @location_facade ||= FacadeFactory.instance.get_instance(FacadeFactory::LOCATION_FACADE, user)
  end

  def default_currency
    @default_currency = MoneyManager.get_default_currency
  end

  def set_overdue_days_range(days)
    case days.to_i
    when 0..29
      '1-29 Days'
    when 30..59
      '30-59 Days'
    when 60..89
      '60-89 Days'
    when 90..119
      '90-119 Days'
    when 120..149
      '120-149 Days'
    when 150..179
      '150-179 Days'
    else
      '180+ Days'
    end
  end

  def generate
    data = {}
    loan_ids = []
    @biz_location_branch.to_a.each do |location_id|
      location = BizLocation.get location_id
      loan_ids << Lending.overdue_loans_for_location_on_date(location, @date) unless location.blank?
    end

    lendings_ids = @paginate == nil ? loan_ids.flatten.to_a.paginate(:page => @page, :per_page => @limit) : loan_ids.flatten.to_a
    
    data[:outstanding_loans] = lendings_ids
    data[:loans] = {}
    lendings = Lending.all(:id => lendings_ids)
    lendings.each do |loan|
      loan_id                    = loan.id
      if loan.is_outstanding_on_date?(@date)
        loan_due_status            = LoanDueStatus.first(:lending_id => loan.id, :due_status => Constants::Loan::DUE, :order => [:on_date.desc, :created_at.desc])
        loan_overdue_status        = LoanDueStatus.first(:lending_id => loan.id, :due_status => Constants::Loan::OVERDUE, :on_date => @date)
        loan_overdue_status        = LoanDueStatus.generate_loan_due_status(loan_id, @date) if loan_overdue_status.blank?
        unless loan_overdue_status.blank?
          member                    = loan.loan_borrower.counterparty
          if member.blank?
            member_id = 'Not Specified'
            member_name = 'Not Specified'
          else
            member_id       = member.id
            member_name     = member.name
          end
          loan_product_name          = loan.lending_product.name rescue "Loan Product Not Available"
          source_of_fund             = FundingLineAddition.get_funder_assigned_to_loan(loan.id).name rescue "Source of Fund not Available"
          loan_account_number        = loan.lan
          loan_disbursed_date        = loan.disbursal_date
          loan_end_date              = loan.last_scheduled_date
          oldest_due_date            = (loan_due_status and (not loan_due_status.nil?)) ? loan_due_status.on_date : loan.scheduled_first_repayment_date
          days_past_due              = loan_overdue_status.day_past_due
          bucket                     = set_overdue_days_range(days_past_due)
          loan_receipt_till_date     = loan.loan_receipts(:effective_on.lte => @date)
          loan_receipt_amt           = LoanReceipt.add_up(loan_receipt_till_date)
          loan_schedule_till_date    = BaseScheduleLineItem.all('loan_base_schedule.lending_id' => loan.id, :on_date.lte => @date).aggregate(:scheduled_principal_due.sum, :scheduled_interest_due.sum) rescue []
          scheduled_principal        = loan_schedule_till_date.blank? ? MoneyManager.default_zero_money : MoneyManager.get_money_instance_least_terms(loan_schedule_till_date[0].to_i)
          scheduled_interest         = loan_schedule_till_date.blank? ? MoneyManager.default_zero_money : MoneyManager.get_money_instance_least_terms(loan_schedule_till_date[1].to_i)
          total_principal_overdue    = scheduled_principal > loan_receipt_amt[:principal_received] ? scheduled_principal - loan_receipt_amt[:principal_received] : MoneyManager.default_zero_money
          total_interest_overdue     = scheduled_interest > loan_receipt_amt[:interest_received] ? scheduled_interest - loan_receipt_amt[:interest_received] : MoneyManager.default_zero_money
          total_overdue              = total_principal_overdue + total_interest_overdue
          par                        = loan.to_money[:disbursed_amount] - loan_receipt_amt[:principal_received]
          center                     = loan.administered_at_origin_location
          center_id                  = center ? center.id : "Not Specified"
          center_name                = center ? center.name : "Not Specified"
          branch                     = loan.accounted_at_origin_location
          branch_name                = branch ? branch.name : "Not Specified"
          branch_id                  = branch ? branch.id : "Not Specified"

          data[:loans][loan.id] = {:member_name => member_name, :member_id => member_id,
            :center_name => center_name, :center_id => center_id, :loan_account_number => loan_account_number,
            :branch_name => branch_name, :branch_id => branch_id,
            :product_name => loan_product_name, :source_of_fund => source_of_fund,
            :loan_disbursed_date => loan_disbursed_date, :loan_end_date => loan_end_date,
            :oldest_due_date => oldest_due_date, :days_past_due => days_past_due,
            :bucket => bucket, :total_principal_overdue => total_principal_overdue, :total_interest_overdue => total_interest_overdue,
            :total_overdue => total_overdue, :par =>  par
          }
        end
      end
    end
    data
  end

  def generate_xls
    @paginate = false
    data = generate

    folder = File.join(Merb.root, "doc", "xls", "company",'reports', self.class.name.split(' ').join().downcase)
    FileUtils.mkdir_p(folder)
    csv_loan_file = File.join(folder, "overdue_detailed_report_(#{@date.to_s}).csv")
    File.new(csv_loan_file, "w").close
    append_to_file_as_csv(headers, csv_loan_file)
    data[:loans].each do |loan_id, s_value|
      value = [s_value[:branch_name], s_value[:center_name], s_value[:member_name], s_value[:product_name], s_value[:source_of_fund], s_value[:loan_disbursed_date], s_value[:loan_end_date], s_value[:oldest_due_date],
        s_value[:days_past_due], s_value[:bucket], s_value[:total_principal_overdue], s_value[:total_interest_overdue],s_value[:total_overdue],s_value[:par]]
      append_to_file_as_csv([value], csv_loan_file)
    end
    File.new(csv_loan_file, "w").close
    return true
  end

  def append_to_file_as_csv(data, filename)
    FasterCSV.open(filename, "a", {:col_sep => "|"}) do |csv|
      data.each do |datum|
        csv << datum
      end
    end
  end

  def headers
    _headers ||= [["Branch Name", "Center Name", "Customer Name", "Product", "Source Of Fund", "Loan Disbursed Date", "Loan End Date", "Oldest Due Date", "Days Past Due", "Bucket", "Total Principal Overdue","Total Interest Overdue","Total Overdue","PAR"]]
  end

end