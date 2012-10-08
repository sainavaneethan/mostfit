namespace :mostfit do
  namespace :periodic do
    require 'fastercsv'

    desc "To be run each day to accrue receipts on loans"
    task :accrue_on_loans, :on_date do |t, args|
      USAGE_TEXT = <<USAGE_TEXT
rake mostfit:periodic:accrue_on_loans[<'yyyy-mm-dd'>]
Accrues on loans as appropriate, including regular accrual,
broken-period interest accrual, and reversal of broken-period interest accrual
USAGE_TEXT

      MY_TASK_NAME = Constants::Tasks::ACCRUE_ON_LOANS_TASK
      begin
        on_date_str = args[:on_date]
        raise ArgumentError, "Date was not specified" unless (on_date_str and not(on_date_str.empty?))

        on_date = Date.parse(on_date_str)
        raise ArgumentError, "#{on_date} is a future date" if on_date > Date.today

        user_facade = FacadeFactory.instance.get_instance(FacadeFactory::USER_FACADE, nil)
        operator = user_facade.get_operator

        reporting_facade = FacadeFactory.instance.get_instance(FacadeFactory::REPORTING_FACADE, operator)
        all_outstanding_loans_on_date = reporting_facade.all_outstanding_loans_on_date(on_date)

        errors = []
        bk = MyBookKeeper.new
        all_outstanding_loans_on_date.each {|loan|
          begin
            bk.accrue_all_receipts_on_loan(loan, on_date)
          rescue => ex
            errors << [loan.id, ex.message]
          end
        }
        
        unless errors.empty?
          error_file_name = Constants::Tasks::error_file_name(MY_TASK_NAME, on_date, DateTime.now)
          error_file_path = File.join(Merb.root, 'log', error_file_name)
          FasterCSV.open(error_file_path, "w") do |csv|
            errors.each do |err|
              csv << err
            end
          end
        end
        
      rescue => ex
        p "Error message: #{ex.message}"
        p USAGE_TEXT
      end
    end
  end
end