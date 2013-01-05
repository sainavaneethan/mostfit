module BookKeeper
  include Constants::LoanAmounts, Constants::Accounting, Constants::Products, Constants::Transaction

  def record_voucher(transaction_summary)
  	#the money category says what kind of transaction this is
  	raise ArgumentError, "Unable to resolve the money category for transaction summary: #{transaction_summary}" unless (transaction_summary and transaction_summary.money_category)
  	money_category = transaction_summary.money_category

  	#the voucher contents come from the transaction summary
  	total_amount, currency, effective_on = transaction_summary.amount, transaction_summary.currency, transaction_summary.effective_on
    notation = nil

  	#the accounting rule is obtained from the money category
  	raise StandardError, "Unable to resolve the accounting rule corresponding to money category: #{money_category}" unless money_category.accounting_rule
  	accounting_rule = money_category.accounting_rule
  	postings = accounting_rule.get_posting_info(total_amount, currency)

  	#any applicable cost centers are resolved
  	branch_id = transaction_summary.branch_id
    raise StandardError, "no branch ID was available for the transaction summary" unless branch_id

    #record voucher
  	Voucher.create_generated_voucher(total_amount, currency, effective_on, postings, notation)
    transaction_summary.set_processed
  end

  def account_for_payment_transaction(payment_transaction, payment_allocation)
    # determine the product action
    product_action = payment_transaction.product_action
    raise Errors::InvalidConfigurationError, "Unable to determine the product action for the payment transaction" unless product_action

    total_amount, currency, effective_on = payment_transaction.amount, payment_transaction.currency, payment_transaction.effective_on
    notation = "Voucher created for #{product_action.to_s.humanize} on #{effective_on}"
    product_accounting_rule = ProductAccountingRule.resolve_rule_for_product_action(product_action)
    if product_action == :loan_preclosure
      account_for_accrual_reverse(Lending.get(payment_transaction.on_product_id), payment_transaction.effective_on)
    end
    postings = product_accounting_rule.get_posting_info(payment_transaction, payment_allocation)
    receipt_type = payment_transaction.receipt_type == Constants::Transaction::PAYMENT ? payment_transaction.receipt_type : Constants::Transaction::RECEIPT
    Voucher.create_generated_voucher(total_amount, receipt_type, currency, effective_on, postings, payment_transaction.performed_at, payment_transaction.accounted_at, notation)
    payment_transaction.update(:accounting => true)
  end

  def account_for_due_generation(loan, payment_allocation, on_date = Date.today)
    # determine the product action
    product_action = :loan_due
    loan_id = loan.id
    client_id = loan.borrower.id
    total_amount = payment_allocation[:total_received]
    performed_at = LoanAdministration.get_administered_at(loan_id, Date.today)
    accounted_at = LoanAdministration.get_accounted_at(loan_id, Date.today)
    product_accounting_rule = ProductAccountingRule.resolve_rule_for_product_action(product_action)
    postings = product_accounting_rule.get_due_generation_posting_info(payment_allocation, performed_at.id, accounted_at.id, loan_id, client_id)
    receipt_type = Constants::Transaction::RECEIPT
    notation = "Voucher created for Loan Due Generation on #{on_date}"
    Voucher.create_generated_voucher(total_amount.amount, receipt_type, total_amount.currency, on_date, postings, performed_at.id, accounted_at.id, notation)
  end

  def account_for_write_off(loan, payment_allocation, on_date = Date.today)
    # determine the product action
    product_action = :write_off
    loan_id = loan.id
    client_id = loan.borrower.id
    received_accruals = AccrualTransaction.all(:accrual_allocation_type => ACCRUE_PRINCIPAL_ALLOCATION, :on_product_type => 'lending', :on_product_id => loan.id, :effective_on.lte => on_date)
    accrual_money = received_accruals.blank? ? MoneyManager.default_zero_money : MoneyManager.get_money_instance_least_terms(received_accruals.map(&:amount).sum.to_i)
    payment_allocation[:total_received] = payment_allocation[:total_received] > accrual_money ? payment_allocation[:total_received] - accrual_money : payment_allocation[:total_received]
    total_amount = payment_allocation[:total_received]
    location_map = LoanAdministration.get_location_map(loan.id, Date.today)
    performed_at = location_map.administered_at
    accounted_at = location_map.accounted_at
    product_accounting_rule = ProductAccountingRule.resolve_rule_for_product_action(product_action)
    postings = product_accounting_rule.get_due_generation_posting_info(payment_allocation, performed_at, accounted_at, loan_id, client_id)
    receipt_type = Constants::Transaction::RECEIPT
    narration = "Voucher created for Loan Write Off on #{on_date}"
    Voucher.create_generated_voucher(total_amount.amount, receipt_type, total_amount.currency, on_date, postings, performed_at, accounted_at, narration)
  end

  def account_for_accrual_reverse(loan, on_date)
    payment_allocation = {}
    product_action = NON_RECEIVED_ACCRUAL_REVERSE
    loan_id = loan.id
    client_id = loan.borrower.id
    principal_accruals = AccrualTransaction.all(:accrual_allocation_type => ACCRUE_PRINCIPAL_ALLOCATION, :on_product_type => 'lending', :on_product_id => loan.id, :effective_on.lte => on_date)
    interest_accruals = AccrualTransaction.all(:accrual_allocation_type => ACCRUE_INTEREST_ALLOCATION, :on_product_type => 'lending', :on_product_id => loan.id, :effective_on.lte => on_date)
    loan_receipts = loan.loan_receipts('payment_transaction.payment_towards' => [PAYMENT_TOWARDS_LOAN_REPAYMENT,PAYMENT_TOWARDS_LOAN_ADVANCE_ADJUSTMENT])
    principal_accrual_money = principal_accruals.blank? ? MoneyManager.default_zero_money : MoneyManager.get_money_instance_least_terms(principal_accruals.map(&:amount).sum.to_i)
    interest_accrual_money = interest_accruals.blank? ? MoneyManager.default_zero_money : MoneyManager.get_money_instance_least_terms(interest_accruals.map(&:amount).sum.to_i)
    principal_received = loan_receipts.blank? ? MoneyManager.default_zero_money : MoneyManager.get_money_instance_least_terms(loan_receipts.map(&:principal_received).sum.to_i)
    interest_received = loan_receipts.blank? ? MoneyManager.default_zero_money : MoneyManager.get_money_instance_least_terms(loan_receipts.map(&:interest_received).sum.to_i)
    reverse_interset = interest_accrual_money > interest_received ? interest_accrual_money - interest_received : MoneyManager.default_zero_money
    reverse_principal = principal_accrual_money > principal_received ? principal_accrual_money - principal_received : MoneyManager.default_zero_money
    reverse_total = reverse_interset + reverse_principal
    if reverse_total > MoneyManager.default_zero_money
      payment_allocation[:total_received] = reverse_total
      payment_allocation[:principal_received] = reverse_principal
      payment_allocation[:interest_received] = reverse_interset
      total_amount = payment_allocation[:total_received]
      location_map = LoanAdministration.get_location_map(loan.id, Date.today)
      performed_at = location_map.administered_at
      accounted_at = location_map.accounted_at
      product_accounting_rule = ProductAccountingRule.resolve_rule_for_product_action(product_action)
      postings = product_accounting_rule.get_due_generation_posting_info(payment_allocation, performed_at, accounted_at, loan_id, client_id)
      receipt_type = Constants::Transaction::RECEIPT
      narration = "Voucher created for Loan Reverse Accrual on #{on_date}"
      Voucher.create_generated_voucher(total_amount.amount, receipt_type, total_amount.currency, on_date, postings, performed_at, accounted_at, narration)
    end
  end

  def self.can_accrue_on_loan_on_date?(loan, on_date)
    loan.is_outstanding_on_date?(on_date) and
      (on_date >= loan.scheduled_first_repayment_date) and
      (on_date >  loan.disbursal_date_value)
  end

  def accrue_all_receipts_on_loan(loan, on_date)
    return unless BookKeeper.can_accrue_on_loan_on_date?(loan, on_date)
    if (loan.schedule_date?(on_date))
      # only accrue regular interest receipts for loans that are scheduled to repay on_date
      accrue_regular_receipts_on_loan(loan, on_date)
    elsif
      if (Constants::Time.is_last_day_of_month?(on_date))
        accrue_broken_period_interest_receipts_on_loan(loan, on_date)
      end
    end
    if (Constants::Time.is_first_day_of_month?(on_date))
      reverse_all_broken_period_interest_receipts(on_date)
    end
  end

  def accrue_all_receipts_on_loan_till_date(loan, till_date)
    loan_schedules = loan.loan_base_schedule.base_schedule_line_items(:on_date.lte => till_date).map(&:on_date).sort rescue []
    loan_schedules.each{|date| accrue_all_receipts_on_loan(loan, date)}

    loan_schedules.group_by{|d| [d.year,d.month]}.values.sort.each do |dates|
      first_date = dates.first.first_day_of_month
      last_date = dates.first.last_day_of_month
      accrue_broken_period_interest_receipts_on_loan(loan, last_date) if loan_schedules.last > last_date
      reverse_all_broken_period_interest_receipts(first_date) if loan_schedules.first < first_date
    end
  end

  def accrue_regular_receipts_on_loan(loan, on_date)
    return unless BookKeeper.can_accrue_on_loan_on_date?(loan, on_date)
    if AccrualTransaction.first(:on_product_id => loan.id, :on_product_type => 'lending', :effective_on => on_date).blank?
      schedule_item = BaseScheduleLineItem.first('loan_base_schedule.lending_id' => loan.id , :on_date => on_date)
      unless schedule_item.blank?
        scheduled_principal_due = schedule_item.to_money[SCHEDULED_PRINCIPAL_DUE]
        scheduled_interest_due  = schedule_item.to_money[SCHEDULED_INTEREST_DUE]
        accrual_temporal_type = ACCRUE_REGULAR
        receipt_type = RECEIPT
        on_product_type, on_product_id = LENDING, loan.id
        by_counterparty_type, by_counterparty_id = Resolver.resolve_counterparty(loan.borrower)
        location_map = LoanAdministration.get_location_map(loan.id, on_date)
        raise ArgumentError, "Location is not defined on #{on_date} for Loan(#{loan.id})" if location_map.blank?
        accounted_at = location_map.accounted_at
        performed_at = location_map.administered_at
        effective_on = on_date

        accrue_principal = AccrualTransaction.record_accrual(ACCRUE_PRINCIPAL_ALLOCATION, scheduled_principal_due, receipt_type, on_product_type, on_product_id, by_counterparty_type, by_counterparty_id, performed_at, accounted_at, effective_on, accrual_temporal_type)
        accrue_interest  = AccrualTransaction.record_accrual(ACCRUE_INTEREST_ALLOCATION, scheduled_interest_due, receipt_type, on_product_type, on_product_id, by_counterparty_type, by_counterparty_id, performed_at, accounted_at, effective_on, accrual_temporal_type)
      end
    end
  end

  def accrue_broken_period_interest_receipts_on_loan(loan, on_date)
    return unless BookKeeper.can_accrue_on_loan_on_date?(loan, on_date)
    broken_period_interest = loan.broken_period_interest_due(on_date)
    accrual_temporal_type = ACCRUE_BROKEN_PERIOD
    receipt_type = RECEIPT
    on_product_type, on_product_id = LENDING, loan.id
    by_counterparty_type, by_counterparty_id = Resolver.resolve_counterparty(loan.borrower)
    location_map = LoanAdministration.get_location_map(loan.id, on_date)
    raise ArgumentError, "Location is not defined on #{on_date} for Loan(#{loan.id})" if location_map.blank?
    accounted_at = location_map.accounted_at
    performed_at = location_map.administered_at
    effective_on = on_date

    accrue_broken_period_interest_receipt = AccrualTransaction.record_accrual(ACCRUE_INTEREST_ALLOCATION, broken_period_interest, receipt_type, on_product_type, on_product_id, by_counterparty_type, by_counterparty_id, performed_at, accounted_at, effective_on, accrual_temporal_type)
  end

  def reverse_all_broken_period_interest_receipts(on_date)
    all_broken_period_interest_receipts_to_reverse = AccrualTransaction.all_broken_period_interest_accruals_not_reversed(on_date - 1)
    all_broken_period_interest_receipts_to_reverse.each { |bpial|
      reversal_accrual = bpial.to_reversed_broken_period_accrual
      raise Errors::DataError, reversal_accrual.errors.first.first unless reversal_accrual.save
      ReversedAccrualLog.record_reversed_accrual_log(bpial, reversal_accrual)
    }
  end

  def account_for_accrual(accrual_transaction)
    accrual_allocation = {:total_accrued => accrual_transaction.accrual_money_amount}
    account_for_payment_transaction(accrual_transaction, accrual_allocation)
  end

  def get_primary_chart_of_accounts
    AccountsChart.first(:name => 'Financial Accounting')
  end

  def setup_counterparty_accounts_chart(for_counterparty)
    AccountsChart.setup_counterparty_accounts_chart(for_counterparty)
  end

  def get_counterparty_accounts_chart(for_counterparty)
    AccountsChart.get_counterparty_accounts_chart(for_counterparty)
  end

  def get_ledger(by_ledger_id)
    Ledger.get(by_ledger_id)
  end

  def get_ledger_opening_balance_and_date(by_ledger_id, cost_center_id = nil)
    ledger = get_ledger(by_ledger_id)
    raise Errors::DataMissingError, "Unable to locate ledger by ID: #{by_ledger_id}" unless ledger
    ledger.opening_balance_and_date(cost_center_id = nil)
  end

  def get_current_ledger_balance(by_ledger_id, cost_center_id = nil)
    get_historical_ledger_balance(by_ledger_id, Date.today, cost_center_id)
  end

  def get_historical_ledger_balance(by_ledger_id, on_date, cost_center_id = nil)
    ledger = get_ledger(by_ledger_id)
    raise Errors::DataMissingError, "Unable to locate ledger by ID: #{by_ledger_id}" unless ledger
    ledger.balance(on_date, cost_center_id)
  end

end

class MyBookKeeper
  include BookKeeper

  def initialize(at_time = DateTime.now)
    @created_at = at_time
  end

  def to_s
    "#{self.class} created at #{@created_at}"
  end

end
