class BranchDateWiseSofDuesCollectionsAndAccrualsReport < Report
  attr_accessor :from_date, :to_date, :funding_line_id

  validates_with_method :funding_line_id, :funding_line_not_selected

  def initialize(params, dates, user)
    @from_date = (dates and dates[:from_date]) ? dates[:from_date] : Date.today - 7
    @to_date   = (dates and dates[:to_date]) ? dates[:to_date] : Date.today
    @name = "Branch Date Wise SOF Dues Collections and Accruals Report from #{@from_date} to #{@to_date}"
    @user = user
    get_parameters(params, user)
  end

  def name
    "Branch-Date Wise SOF Dues Collections and Accruals Report from #{@from_date} to #{@to_date}"
  end

  def self.name
    "Branch-Date Wise SOF Dues Collections and Accruals Report"
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

  def generate

    reporting_facade = get_reporting_facade(@user)
    location_facade  = get_location_facade(@user)
    data = {}
    loan_ids = FundingLineAddition.all(:funding_line_id => @funding_line_id).aggregate(:lending_id)
    preclosure_loans = LoanStatusChange.status_between_dates(LoanLifeCycle::PRECLOSED_LOAN_STATUS, @from_date, @to_date).lending
    loan_ids.each do |loan_id|
      loan = Lending.get(loan_id)
      branch = BizLocation.get(loan.accounted_at_origin)
      branch_name = branch ? branch.name : "Not Specified"
      branch_id = branch ? branch.id : "Not Specified"
      branch_preclosure_loans = preclosure_loans.select{|lending| lending.accounted_at_origin == branch_id}
      data[branch_id] = {}
      (@from_date..@to_date).each do |on_date|

        preclosure_collect = interest_accured     = disbursed_amount       = outstanding_principal = emi_collect_interest = MoneyManager.default_zero_money
        dues_emi_interest  = dues_emi_total       = dues_emi_principal     = emi_collect_principal = emi_collect_total = MoneyManager.default_zero_money
        fee_collect        = total_fee_collection = preclosure_fee_collect = MoneyManager.default_zero_money
        unless check_holiday_on_date(on_date)

          branch_loans = LoanAdministration.get_loans_accounted(branch_id, on_date).compact
          branch_loans.each do |lending|
            if lending.is_outstanding_on_date?(on_date)
              dues_emi_principal    += lending.actual_principal_outstanding(on_date) || MoneyManager.default_zero_money
              dues_emi_interest     += lending.actual_interest_outstanding(on_date)  || MoneyManager.default_zero_money
              dues_emi_total        = dues_emi_principal + dues_emi_interest
              emi_collect_principal += lending.principal_received_on_date(on_date)
              emi_collect_interest  += lending.interest_received_on_date(on_date)
              emi_collect_total     = emi_collect_principal + emi_collect_interest
              interest_accured      = interest_accured      + lending.accrued_interim_interest(@from_date, @to_date)
              disbursed_amount      = disbursed_amount      + lending.to_money[:disbursed_amount] if lending.disbursal_date == on_date
              outstanding_principal = outstanding_principal + lending.actual_principal_outstanding(on_date)
            end
          end
        
          fee_collection         = FeeReceipt.all_paid_loan_fee_receipts_on_accounted_at(branch_id, on_date)
          fee_collect            = fee_collection[:loan_fee_receipts].blank? ? MoneyManager.default_zero_money  : Money.new(fee_collection[:loan_fee_receipts].map(&:fee_amount).sum.to_i, default_currency)
          preclosure_fee_collect = fee_collection[:loan_preclousure_fee_receipts].blank? ? MoneyManager.default_zero_money  : Money.new(fee_collection[:loan_preclousure_fee_receipts].map(&:fee_amount).sum.to_i, default_currency)

          branch_preclosure_loans.each do |lending|
            status_change      = lending.loan_status_changes(:to_status => LoanLifeCycle::PRECLOSED_LOAN_STATUS, :effective_on => on_date)
            preclosure_collect += lending.loan_receipts.last.to_money[:principal_received] unless status_change.blank?
          end

          total_fee_collection = fee_collect + preclosure_fee_collect + preclosure_collect
        end
        data[branch_id][on_date] = {
          :branch_name => branch_name, :branch_id => branch_id, :on_date => on_date,
          :dues_emi_principal => dues_emi_principal , :dues_emi_interest => dues_emi_interest, :dues_emi_total => dues_emi_total,
          :emi_collect_principal => emi_collect_principal, :emi_collect_interest => emi_collect_interest, :emi_collect_total => emi_collect_total,
          :loan_fee_collect => fee_collect, :preclosure_collect_fee => preclosure_fee_collect, :preclosure_collect => preclosure_collect, :total_fee_collect => total_fee_collection,
          :interest_accrued => interest_accured, :disbursed_amount => disbursed_amount, :outstanding_principal => outstanding_principal
        }
      end
    end
    data
  end

  def check_holiday_on_date(date)
    week_day = date.strftime('%A')
    return ['Saturday', 'Sunday'].include?(week_day)
  end

  def funding_line_not_selected
    return [false, "Please select Funding Line"] if self.respond_to?(:funding_line_id) and not self.funding_line_id
    return true
  end

end