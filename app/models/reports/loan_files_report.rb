class LoanFilesReport < Report
  attr_accessor :branch_for_loan_application_report, :center_for_loan_application_report, :effective_date

  def initialize(params, date, user)
    @date = date.blank? ? Date.today : date
    @name   = "Report on #{@date}"
    @branch_id = params[:branch_for_loan_application_report] rescue ""
    @center_id = params[:center_for_loan_application_report] rescue ""
    get_parameters(params, user)
  end

  def name
    "Loan File Report on #{@date}"
  end

  def self.name
    "Loan File Report"
  end

  def generate
    condition_hash = {}
    loan_file = {}
    count = 1
    condition_hash.merge!(:at_center_id => @center_id) unless @center_id.blank?
    condition_hash.merge!(:at_branch_id => @branch_id) unless @branch_id.blank?
    loan_files = LoanFile.all(condition_hash)
    loan_files.group_by{|x| [x.at_branch_id,x.at_center_id]}.each do |c, value|
      loan_file.merge!(count => {c[0] => { c[1] => { c[2] => value.count}}})
      count = count + 1
    end
    loan_file
  end
  
end