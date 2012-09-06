class ReportingFacade < StandardFacade
  include Constants::Transaction, Constants::Products

  # Loans scheduled to repay on date

  def all_outstanding_loans_scheduled_on_date(on_date = Date.today)
    outstanding_loans = all_outstanding_loans_on_date(on_date)
    outstanding_loans.select {|loan| loan.schedule_date?(on_date)}
  end

  def all_oustanding_loans_scheduled_on_date_with_advance_balances(on_date = Date.today)
    outstanding_scheduled_on_date = all_outstanding_loans_scheduled_on_date(on_date)
    outstanding_scheduled_on_date.select {|loan| (loan.advance_balance(on_date) > loan.zero_money_amount)}
  end

  def all_oustanding_loan_IDs_scheduled_on_date_with_advance_balances(on_date = Date.today)
    get_ids(all_oustanding_loans_scheduled_on_date_with_advance_balances(on_date))
  end

  #this method will return due collected and due collectable per location on a date.
  def total_dues_collected_and_collectable_per_location_on_date(at_location_id, on_date = Date.today)
    result = {}
    schedule_principal_due = schedule_interest_due = schedule_total_due = MoneyManager.default_zero_money
    principal_collected = interest_collected = total_collected = MoneyManager.default_zero_money
    loans = LoanAdministration.get_loans_administered(at_location_id, on_date).compact
    loans.each do |loan|
      schedule_principal_due += (loan.scheduled_principal_due(on_date) || MoneyManager.default_zero_money)
      schedule_interest_due += (loan.scheduled_interest_due(on_date) || MoneyManager.default_zero_money)
      schedule_total_due += (loan.scheduled_total_due(on_date) || MoneyManager.default_zero_money)
      principal_collected += (loan.principal_received_on_date(on_date) || MoneyManager.default_zero_money)
      interest_collected += (loan.interest_received_on_date(on_date) || MoneyManager.default_zero_money)
      total_collected += (principal_collected + interest_collected)
    end
    result = {:schedule_principal_due => schedule_principal_due, :schedule_interest_due => schedule_interest_due, :schedule_total_due => schedule_total_due, :principal_collected => principal_collected, :interest_collected => interest_collected, :total_collected => total_collected}
  end

  #this function will give back the list of staff_members per location.
  def staff_members_per_location_on_date(at_location_id, on_date)
    params = {:at_location_id => at_location_id, :effective_on.lte => on_date}
    staffs = StaffPosting.all(params)
    staffs
  end

  #this function will give back the list of location which is managed by staff.
  def locations_managed_by_staffs_on_date(staff_id, on_date)
    params = {:manager_staff_id => staff_id, :effective_on => on_date}
    location_ids_array = LocationManagement.locations_managed_by_staff(staff_id, on_date).map{|lm| lm.managed_location_id}
    location_ids_array
  end

  # Allocations

  def total_loan_allocation_receipts_accounted_at_locations_on_value_date(on_date, *at_location_ids_ary)
    total_loan_allocation_receipts_at_locations_on_value_date(on_date, TRANSACTION_ACCOUNTED_AT, at_location_ids_ary)
  end

  #this method is to find out total loan allocation accounted at a particular location for a date range specified.
  def total_loan_allocation_receipts_accounted_at_locations_for_date_range(on_date, till_date, *at_location_ids_ary)
    total_loan_allocation_receipts_at_locations_for_date_range(on_date, till_date, TRANSACTION_ACCOUNTED_AT, at_location_ids_ary)
  end

  def total_loan_allocation_receipts_performed_at_locations_on_value_date(on_date, *at_location_ids_ary)
    total_loan_allocation_receipts_at_locations_on_value_date(on_date, TRANSACTION_PERFORMED_AT, at_location_ids_ary)
  end

  # Outstanding loan IDs by location

  def all_outstanding_loan_ids_accounted_at_locations_on_date(on_date, *at_location_ids_ary)
    all_outstanding_loan_ids_at_locations_on_date(on_date, Constants::Loan::ACCOUNTED_AT, at_location_ids_ary)
  end

  def all_outstanding_loan_ids_administered_at_locations_on_date(on_date, *at_location_ids_ary)
    all_outstanding_loan_ids_at_locations_on_date(on_date, Constants::Loan::ADMINISTERED_AT, at_location_ids_ary)
  end

  def all_outstanding_loans_on_date(on_date = Date.today, accounted_at = nil, administered_at = nil)
    search = {}
    search[:accounted_at_origin] = accounted_at unless accounted_at.blank?
    search[:administered_at_origin] = administered_at unless administered_at.blank?
    Lending.all(search).select{|loan| loan.is_outstanding_on_date?(on_date)}
  end
  
  def all_outstanding_loan_IDs_on_date(on_date = Date.today)
    get_ids(all_outstanding_loans_on_date(on_date))
  end

  # Outstanding loan balances

  def sum_all_outstanding_loans_balances_accounted_at_locations_on_date(on_date, *at_location_ids_ary)
    balances_grouped_by_location = all_outstanding_loans_balances_accounted_at_locations_on_date(on_date, at_location_ids_ary)
    sum_of_balances_by_location = {}
    balances_grouped_by_location.each { |at_location_id, balances_map|
      sum_of_balances_by_location[at_location_id] = Money.add_money_hash_values(MoneyManager.get_default_currency, *balances_map.values)
    }
    sum_of_balances_by_location
  end

  #this function will give the total amount outstanding for loans disbursed till date.
  def sum_all_outstanding_loans
    loan_ids = Lending.all(:disbursal_date.lte => Date.today).aggregate(:id)
    outstanding_amount = MoneyManager.default_zero_money
    loan_ids.each do |l|
      loan = Lending.get(l)
      next unless loan.is_outstanding?
      outstanding_amount += loan.actual_total_outstanding
    end
    outstanding_amount
  end

  #this functions gives the repayments details till date.
  def sum_all_repayments
    result = {}
    params = {:effective_on.lt => Date.today, :loan_recovery => 0.0, "lending.status.not" => :repaid_loan_status}
    principal_received = LoanReceipt.all(params).aggregate(:principal_received.sum)
    interest_received = LoanReceipt.all(params).aggregate(:interest_received.sum)
    advance_received = LoanReceipt.all(params).aggregate(:advance_received.sum)
    advance_adjusted = LoanReceipt.all(params).aggregate(:advance_adjusted.sum)
    total_received = (principal_received || 0) + (interest_received || 0)
    principal_money_amount_received = Money.new(principal_received.to_i, :INR).to_s
    interest_money_amount_received = Money.new(interest_received.to_i, :INR).to_s
    advance_money_amount_received = Money.new(advance_received.to_i, :INR).to_s
    advance_money_amount_adjusted = Money.new(advance_adjusted.to_i, :INR).to_s
    total_money_amount_received = Money.new(total_received.to_i, :INR).to_s
    result = {:principal_received => principal_money_amount_received, :interest_received => interest_money_amount_received, :advance_received => advance_money_amount_received, :advance_adjusted => advance_money_amount_adjusted, :total_received => total_money_amount_received}
  end

  #this function gives the fee payments.
  def sum_all_fee_receipts
    params = {:effective_on.lt => Date.today}
    fee_receipt = FeeReceipt.all(params).aggregate(:fee_amount.sum)
    fee_money_amount_receipt = Money.new(fee_receipt.to_i, :INR).to_s
    result = {:fee_receipt => fee_money_amount_receipt}
  end

  #this function gives all the pre-closures and write-off's values.
  def sum_all_pre_closure_and_write_off_payments
    result = {}
    written_off_params = {:effective_on.lt => Date.today, "lending.status" => :written_off_loan_status}
    pre_closure_params = {:effective_on.lt => Date.today, "lending.status" => :repaid_loan_status}
    written_off_amount = LoanReceipt.all(written_off_params).aggregate(:loan_recovery.sum)
    principal_received = LoanReceipt.all(pre_closure_params).aggregate(:principal_received.sum)
    interest_received = LoanReceipt.all(pre_closure_params).aggregate(:interest_received.sum)
    pre_closure_amount = (principal_received || 0) + (interest_received || 0)
    written_off_money_amount = Money.new(written_off_amount.to_i, :INR).to_s
    pre_closure_money_amount = Money.new(pre_closure_amount.to_i, :INR).to_s
    result = {:written_off_amount => written_off_money_amount, :pre_closure_amount => pre_closure_money_amount}
  end

  #this is the method to find out outstanding loans_balances for a date range.
  def sum_all_outstanding_loans_balances_accounted_at_locations_for_date_range(on_date, till_date, *at_location_ids_ary)
    balances_grouped_by_location = all_outstanding_loans_balances_accounted_at_locations_for_date_range(on_date, till_date, at_location_ids_ary)
    sum_of_balances_by_location = {}
    balances_grouped_by_location.each { |at_location_id, balances_map|
      sum_of_balances_by_location[at_location_id] = Money.add_money_hash_values(MoneyManager.get_default_currency, *balances_map.values)
    }
    sum_of_balances_by_location
  end

  def sum_all_outstanding_loans_balances_administered_at_locations_on_date(on_date, *at_location_ids_ary)
    balances_grouped_by_location = all_outstanding_loans_balances_administered_at_locations_on_date(on_date, at_location_ids_ary)
    sum_of_balances_by_location = {}
    balances_grouped_by_location.each { |at_location_id, balances_map|
      sum_of_balances_by_location[at_location_id] = Money.add_money_hash_values(MoneyManager.get_default_currency, *balances_map.values)
    }
    sum_of_balances_by_location
  end

  def all_outstanding_loans_balances_accounted_at_locations_on_date(on_date, *at_location_ids_ary)
    all_outstanding_loans_balances_at_locations_on_date(on_date, Constants::Loan::ACCOUNTED_AT, at_location_ids_ary)
  end

  #method to get all outstanding loan_balances accounted_at locations for date range.
  def all_outstanding_loans_balances_accounted_at_locations_for_date_range(on_date, till_date, *at_location_ids_ary)
    all_outstanding_loans_balances_at_locations_for_date_range(on_date, till_date, Constants::Loan::ACCOUNTED_AT, at_location_ids_ary)
  end

  def all_outstanding_loans_balances_administered_at_locations_on_date(on_date, *at_location_ids_ary)
    all_outstanding_loans_balances_at_locations_on_date(on_date, Constants::Loan::ADMINISTERED_AT, at_location_ids_ary)
  end

  def loan_balances_for_loan_ids_on_date(on_date, *for_loan_ids_ary)
    loan_ids_array = *for_loan_ids_ary.to_a
    loan_balances_by_loan_id = {}
    if loan_ids_array.is_a?(Fixnum)
      for_loan_id = loan_ids_array
      due_status_record = LoanDueStatus.most_recent_status_record_on_date(for_loan_id, on_date)
      loan_balances_by_loan_id[for_loan_id] = due_status_record.to_money if due_status_record
    else
      loan_ids_array.each { |for_loan_id|
        due_status_record = LoanDueStatus.most_recent_status_record_on_date(for_loan_id, on_date)
        loan_balances_by_loan_id[for_loan_id] = due_status_record.to_money if due_status_record
      }
    end
    loan_balances_by_loan_id
  end

  #this method id to find out loan_balances for loan_ids for a date range.
  def loan_balances_for_loan_ids_for_date_range(on_date, *for_loan_ids_ary)
    loan_ids_array = *for_loan_ids_ary.to_a
    loan_balances_by_loan_id = {}
    loan_ids_array1 = loan_ids_array.uniq
    if (loan_ids_array1 and (not loan_ids_array1.empty?))
      loan_ids_array1.each { |for_loan_id|
        due_status_record = LoanDueStatus.most_recent_status_record_on_date(for_loan_id, on_date)
        loan_balances_by_loan_id[for_loan_id] = due_status_record.to_money if due_status_record
      }
    end
    loan_balances_by_loan_id
  end

  # QUERIES
  #performed_at is nominally a center location
  #accounted_at is nominally a branch location
  
  def all_receipts_on_loans_performed_at_locations_on_value_date(on_date, *at_location_ids_ary)
    location_ids_array = *at_location_ids_ary.to_a
    query = PaymentTransaction.all(:effective_on => on_date, :receipt_type => RECEIPT, :on_product_type => LENDING, :performed_at => location_ids_array)
    count = query.count
    sum_amount = query.aggregate(:amount.sum)
    sum_money_amount = sum_amount ? to_money_amount(sum_amount) : zero_money_amount
    {:count => count, :total_amount => sum_money_amount}
  end

  def all_receipts_on_loans_accounted_at_locations_on_value_date(on_date, *at_location_ids_ary)
    location_ids_array = *at_location_ids_ary.to_a
    query = PaymentTransaction.all(:effective_on => on_date, :receipt_type => RECEIPT, :on_product_type => LENDING, :accounted_at => location_ids_array)
    count = query.count
    sum_amount = query.aggregate(:amount.sum)
    sum_money_amount = sum_amount ? to_money_amount(sum_amount) : zero_money_amount
    {:count => count, :total_amount => sum_money_amount}
  end

  #this method is to find out loan_receipts accounted at location for a specified date range.
  def all_receipts_on_loans_accounted_at_locations_for_date_range(on_date, till_date, *at_location_ids_ary)
    location_ids_array = *at_location_ids_ary.to_a
    query = PaymentTransaction.all(:effective_on.gte => on_date, :effective_on.lte => till_date, :receipt_type => RECEIPT, :on_product_type => LENDING, :accounted_at => location_ids_array)
    count = query.count
    sum_amount = query.aggregate(:amount.sum)
    sum_money_amount = sum_amount ? to_money_amount(sum_amount) : zero_money_amount
    {:count => count, :total_amount => sum_money_amount}
  end

  def all_payments_on_loans_performed_at_locations_on_value_date(on_date, *at_location_ids_ary)
    location_ids_array = *at_location_ids_ary.to_a
    query = PaymentTransaction.all(:effective_on => on_date, :receipt_type => PAYMENT, :on_product_type => LENDING, :performed_at => location_ids_array)
    count = query.count
    sum_amount = query.aggregate(:amount.sum)
    sum_money_amount = sum_amount ? to_money_amount(sum_amount) : zero_money_amount
    {:count => count, :total_amount => sum_money_amount}
  end

  def all_payments_on_loans_accounted_at_locations_on_value_date(on_date, *at_location_ids_ary)
    location_ids_array = *at_location_ids_ary.to_a
    query = PaymentTransaction.all(:effective_on => on_date, :receipt_type => PAYMENT, :on_product_type => LENDING, :accounted_at => location_ids_array)
    count = query.count
    sum_amount = query.aggregate(:amount.sum)
    sum_money_amount = sum_amount ? to_money_amount(sum_amount) : zero_money_amount
    {:count => count, :total_amount => sum_money_amount}
  end

  #this method is to find out payments on loans accounted_at locations in a specified date range.
  def all_payments_on_loans_accounted_at_locations_for_date_range(on_date, till_date, *at_location_ids_ary)
    location_ids_array = *at_location_ids_ary.to_a
    query = PaymentTransaction.all(:effective_on.gte => on_date, :effective_on.lte => till_date, :receipt_type => PAYMENT, :on_product_type => LENDING, :accounted_at => location_ids_array)
    count = query.count
    sum_amount = query.aggregate(:amount.sum)
    sum_money_amount = sum_amount ? to_money_amount(sum_amount) : zero_money_amount
    {:count => count, :total_amount => sum_money_amount}
  end

  def net_payments_on_loans_performed_at_locations_on_value_date(on_date, *at_location_ids_ary)
    payments = all_payments_on_loans_performed_at_locations_on_value_date(on_date, *at_location_ids_ary)
    receipts = all_receipts_on_loans_performed_at_locations_on_value_date(on_date, *at_location_ids_ary)

    total_payments_amount = payments[:total_amount]; total_receipts_amount = receipts[:total_amount]
    net_transaction_type = total_payments_amount > total_receipts_amount ? PAYMENT : RECEIPT
    net_amount = total_payments_amount - total_receipts_amount
    total_count = payments[:count] + receipts[:count]

    {:count => total_count, :total_amount => net_amount}
  end

  def net_payments_on_loans_accounted_at_locations_on_value_date(on_date, *at_location_ids_ary)
    payments = all_payments_on_loans_accounted_at_locations_on_value_date(on_date, *at_location_ids_ary)
    receipts = all_receipts_on_loans_accounted_at_locations_on_value_date(on_date, *at_location_ids_ary)

    total_payments_amount = payments[:total_amount]; total_receipts_amount = receipts[:total_amount]
    net_transaction_type = total_payments_amount > total_receipts_amount ? PAYMENT : RECEIPT
    net_amount = Money.net_amount(total_payments_amount, total_receipts_amount)
    total_count = payments[:count] + receipts[:count]

    {:count => total_count, :total_amount => net_amount}
  end

  #this method is for calculating new payments on loans accounted at locations in a specified date range.
  def net_payments_on_loans_accounted_at_locations_for_date_range(on_date, till_date, *at_location_ids_ary)
    payments = all_payments_on_loans_accounted_at_locations_for_date_range(on_date, till_date, *at_location_ids_ary)
    receipts = all_receipts_on_loans_accounted_at_locations_for_date_range(on_date, till_date, *at_location_ids_ary)

    total_payments_amount = payments[:total_amount]; total_receipts_amount = receipts[:total_amount]
    net_transaction_type = total_payments_amount > total_receipts_amount ? PAYMENT : RECEIPT
    net_amount = Money.net_amount(total_payments_amount, total_receipts_amount)
    total_count = payments[:count] + receipts[:count]

    {:count => total_count, :total_amount => net_amount}
  end

  # Loans by status at locations on date

  def loans_applied_by_branches_on_date(on_date, *at_branch_ids_ary)
    aggregate_loans_by_branches_for_status_on_date(:applied, on_date, *at_branch_ids_ary)
  end

  #This is the method to find out the loans applied by branches in a date range.
  def loans_applied_by_branches_for_date_range(on_date, till_date, *at_branch_ids_ary)
    aggregate_loans_by_branches_for_status_during_a_date_range(:applied, on_date, till_date, *at_branch_ids_ary)
  end

  def loans_applied_by_centers_on_date(on_date, *at_center_ids_ary)
    loans_by_centers_for_status_on_date(:applied, on_date, *at_center_ids_ary)
  end

  def loans_approved_by_branches_on_date(on_date, *at_branch_ids_ary)
    aggregate_loans_by_branches_for_status_on_date(:approved, on_date, *at_branch_ids_ary)
  end

  #This method is to find out loans approved by branches in a date range.
  def loans_approved_by_branches_for_date_range(on_date, till_date, *at_branch_ids_ary)
    aggregate_loans_by_branches_for_status_during_a_date_range(:approved, on_date, till_date, *at_branch_ids_ary)
  end

  def loans_approved_by_centers_on_date(on_date, *at_center_ids_ary)
    loans_by_centers_for_status_on_date(:approved, on_date, *at_center_ids_ary)
  end

  def loans_scheduled_for_disbursement_by_branches_on_date(on_date, *at_branch_ids_ary)
    aggregate_loans_by_branches_for_status_on_date(:scheduled_for_disbursement, on_date, *at_branch_ids_ary)
  end

  #this is the method to find out the loans scheduled for disbursement by branches in a date range.
  def loans_scheduled_for_disbursement_by_branches_for_date_range(on_date, till_date, *at_branch_ids_ary)
    aggregate_loans_by_branches_for_status_during_a_date_range(:scheduled_for_disbursement, on_date, till_date, *at_branch_ids_ary)
  end

  def loans_scheduled_for_disbursement_by_centers_on_date(on_date, *at_center_ids_ary)
    loans_by_centers_for_status_on_date(:scheduled_for_disbursement, on_date, *at_center_ids_ary)
  end

  def individual_loans_disbursed_by_branches_on_date(on_date, *at_branch_ids_ary)
    individual_loans_by_branches_for_status_on_date(:disbursed, on_date, *at_branch_ids_ary)
  end

  def loans_disbursed_by_branches_on_date(on_date, *at_branch_ids_ary)
    aggregate_loans_by_branches_for_status_on_date(:disbursed, on_date, *at_branch_ids_ary)
  end

  #this is the method to find out loans disbursed by branches for a date range.
  def loans_disbursed_by_branches_for_date_range(on_date, till_date, *at_branch_ids_ary)
    aggregate_loans_by_branches_for_status_during_a_date_range(:disbursed, on_date, till_date, *at_branch_ids_ary)
  end

  def loans_disbursed_by_branches_and_lending_products_on_date(on_date, lending_product_list, *at_branch_ids_ary)
    aggregate_loans_by_branches_and_lending_products_for_status_on_date(:disbursed, on_date, lending_product_list, *at_branch_ids_ary)
  end

  def individual_loans_disbursed_by_centers_on_date(on_date, *at_center_ids_ary)
    individual_loans_by_centers_for_status_on_date(:disbursed, on_date, *at_center_ids_ary)
  end

  def loans_disbursed_by_centers_on_date(on_date, *at_center_ids_ary)
    loans_by_centers_for_status_on_date(:disbursed, on_date, *at_center_ids_ary)
  end

  def all_aggregate_fee_receipts_by_branches(on_date, till_date = on_date, *at_branch_ids_ary)
    from_date, to_date = Constants::Time.ordered_dates(on_date, till_date)
    query = {:effective_on.gte => from_date, :effective_on.lte => to_date}
    query[:accounted_at] = at_branch_ids_ary if (at_branch_ids_ary and (not (at_branch_ids_ary.empty?)))
    query_results = FeeReceipt.all(query)

    count = query_results.count
    sum_amount = query_results.aggregate(:fee_amount.sum)
    sum_money_amount = sum_amount ? to_money_amount(sum_amount) : zero_money_amount
    {:count => count, :total_amount => sum_money_amount}
  end

  def aggregate_fee_receipts_on_loans_by_branches(on_date, till_date = on_date, *at_branch_ids_ary)
    from_date, to_date = Constants::Time.ordered_dates(on_date, till_date)
    query = {:effective_on.gte => from_date, :effective_on.lte => to_date}
    query[:fee_applied_on_type] = Constants::Fee::FEE_ON_LOAN
    query[:accounted_at] = at_branch_ids_ary if (at_branch_ids_ary and (not (at_branch_ids_ary.empty?)))
    query_results = FeeReceipt.all(query)

    count = query_results.count
    sum_amount = query_results.aggregate(:fee_amount.sum)
    sum_money_amount = sum_amount ? to_money_amount(sum_amount) : zero_money_amount
    {:count => count, :total_amount => sum_money_amount}
  end

  def all_aggregate_fee_dues_by_branches(on_date, till_date = on_date, *at_branch_ids_ary)
    from_date, to_date = Constants::Time.ordered_dates(on_date, till_date)
    query = {:applied_on.gte => from_date, :applied_on.lte => to_date}
    query[:accounted_at] = at_branch_ids_ary if (at_branch_ids_ary and (not (at_branch_ids_ary.empty?)))
    query_results = FeeInstance.all(query)

    count = query_results.count
    sum_amount = MoneyManager.default_zero_money
    query_results.each do |x|
      sum_amount += x.effective_total_amount(on_date)
    end
    sum_money_amount = sum_amount
    {:count => count, :total_amount => sum_money_amount}
  end

  #following function is to find out the fees due per loan.
  def all_fees_due_per_loan(loan_id, on_date)
    fee_amount = MoneyManager.default_zero_money
    loan = Lending.get(loan_id)
    unpaid_loan_fee_instances = loan.unpaid_loan_fees.map{|fi| fi.simple_fee_product_id}
    unpaid_loan_fee_instances.each do |ulfi|
      simple_fee_product = SimpleFeeProduct.get(ulfi)
      fee_amount += simple_fee_product.effective_total_amount(on_date)
    end
    fee_amount
  end

  def total_money_deposited_on_date_at_locations(on_date, *at_location_id)
    query = {:created_on => on_date, :at_location_id => at_location_id}
    all_money_deposits = MoneyDeposit.all(query)
    
    count = all_money_deposits.count
    sum_amount = all_money_deposits.aggregate(:amount.sum)
    sum_money_amount = sum_amount ? to_money_amount(sum_amount) : zero_money_amount
    {:count => count, :total_amount => sum_money_amount}
  end

  def total_money_deposited_pending_verification_until_date_at_locations(on_date, *at_location_id)
    query = {:created_on.lte => on_date, :at_location_id => at_location_id, :verification_status => Constants::MoneyDepositVerificationStatus::PENDING_VERIFICATION}
    all_money_deposits = MoneyDeposit.all(query)

    count = all_money_deposits.count
    sum_amount = all_money_deposits.aggregate(:amount.sum)
    sum_money_amount = sum_amount ? to_money_amount(sum_amount) : zero_money_amount
    {:count => count, :total_amount => sum_money_amount}
  end

  def total_money_deposited_verified_confirmed_on_date_at_locations(on_date, *at_location_id)
    query = {:created_on => on_date, :at_location_id => at_location_id, :verification_status => Constants::MoneyDepositVerificationStatus::VERIFIED_CONFIRMED}
    all_money_deposits = MoneyDeposit.all(query)

    count = all_money_deposits.count
    sum_amount = all_money_deposits.aggregate(:amount.sum)
    sum_money_amount = sum_amount ? to_money_amount(sum_amount) : zero_money_amount
    {:count => count, :total_amount => sum_money_amount}
  end

  def total_money_deposited_verified_rejected_on_date_at_locations(on_date, *at_location_id)
    query = {:created_on => on_date, :at_location_id => at_location_id, :verification_status => Constants::MoneyDepositVerificationStatus::VERIFIED_REJECTED}
    all_money_deposits = MoneyDeposit.all(query)

    count = all_money_deposits.count
    sum_amount = all_money_deposits.aggregate(:amount.sum)
    sum_money_amount = sum_amount ? to_money_amount(sum_amount) : zero_money_amount
    {:count => count, :total_amount => sum_money_amount}
  end
  
  def outstanding_loans_exceeding_days_past_due(days_past_due, accounted_at = nil, administered_at = nil)
    outstanding_loans = all_outstanding_loans_on_date(Date.today, accounted_at, administered_at)
    raise ArgumentError, "Days past due: #{days_past_due} must be a valid number of days" unless (days_past_due and (days_past_due > 0))
    outstanding_loans.select {|loan| (loan.days_past_due >= days_past_due)}
  end

  def loans_eligible_for_write_off(days_past_due = configuration_facade.days_past_due_eligible_for_writeoff, accounted_at =nil,administered_at =nil)
    raise Errors::InvalidConfigurationError, "Days past due for write off has not been configured" unless days_past_due
    [days_past_due, loans_past_due(days_past_due, accounted_at, administered_at)]
  end

  def loans_past_due(by_number_of_days = 1, accounted_at = nil, administered_at = nil)
    outstanding_loans_exceeding_days_past_due(by_number_of_days, accounted_at, administered_at)
  end

  def all_accrual_transactions_recorded_on_date(on_date)
    AccrualTransaction.all(:created_at.gt => on_date, :created_at.lt => (on_date + 1))
  end

  #this function gives back the total amount paid towards written-off status for loan.
  def aggregate_loans_by_branches_for_written_off_status_on_date(for_status, on_date, *at_branch_ids_ary)
    loan_status, date_to_query = LoanLifeCycle::STATUSES_DATES_FOR_WRITE_OFF[for_status]
    loan_query = {:status => loan_status, date_to_query => on_date}
    loan_query[:accounted_at_origin] = at_branch_ids_ary if (at_branch_ids_ary and (not (at_branch_ids_ary.empty?)))
    loan_ids = Lending.all(loan_query).aggregate(:id)

    query = {:effective_on => on_date, :lending_id => loan_ids}
    query_results = LoanReceipt.all(query)

    sum_amount = (query_results and (not query_results.empty?)) ? query_results.aggregate(:loan_recovery.sum) : 0
    sum_money_amount = sum_amount ? to_money_amount(sum_amount) : zero_money_amount
    {:total_amount => sum_money_amount}
  end

  #this function gives back the total amount paid towards pre-closure status for loan.
  def aggregate_loans_by_branches_for_pre_closure_status_on_date(for_status, on_date, *at_branch_ids_ary)
    loan_status = LoanLifeCycle::STATUSES_DATES_FOR_PRE_CLOSURE[for_status]
    loan_query = {:status => loan_status}
    loan_query[:accounted_at_origin] = at_branch_ids_ary if (at_branch_ids_ary and (not (at_branch_ids_ary.empty?)))
    loan_ids = Lending.all(loan_query).aggregate(:id)

    status_change_query = {:to_status => loan_status, :lending_id => loan_ids, :effective_on => on_date}
    status_change_loan_ids = (LoanStatusChange.all(status_change_query) and (not LoanStatusChange.all(status_change_query).empty?)) ? LoanStatusChange.all(status_change_query).aggregate(:lending_id) : []

    query = {:effective_on => on_date, :lending_id => status_change_loan_ids}
    query_results = LoanReceipt.all(query)

    sum_principal_received = (query_results and (not query_results.empty?)) ? query_results.aggregate(:principal_received.sum) : 0
    sum_interest_received = (query_results and (not query_results.empty?)) ? query_results.aggregate(:interest_received.sum) : 0
    sum_principal_received_money_amount = sum_principal_received ? to_money_amount(sum_principal_received) : zero_money_amount
    sum_interest_received_money_amount = sum_interest_received ? to_money_amount(sum_interest_received) : zero_money_amount
    total_amount_received = sum_principal_received_money_amount + sum_interest_received_money_amount
    {:principal_received => sum_principal_received_money_amount, :interest_received => sum_interest_received_money_amount, :total_received => total_amount_received}
  end

  #this function gives loan amounts and count for various statuses.
  def aggregate_loans_for_status(for_status, on_date)
    loan_status, date_to_query, amount_to_sum = LoanLifeCycle::STATUSES_DATES_SUM_AMOUNTS[for_status]
    query = {:status => loan_status, date_to_query.lt => on_date}
    query_results = Lending.all(query)

    count = query_results.count
    sum_amount = query_results.aggregate(amount_to_sum)
    sum_money_amount = sum_amount ? to_money_amount(sum_amount) : zero_money_amount
    {:count => count, :total_amount => sum_money_amount}
  end

  private

  def individual_loans_by_branches_for_status_on_date(for_status, on_date, *at_branch_ids_ary)
    loan_status, date_to_query, ignore_val = LoanLifeCycle::STATUSES_DATES_SUM_AMOUNTS[for_status]
    query = {:status => loan_status, date_to_query => on_date}
    query[:accounted_at_origin] = at_branch_ids_ary if (at_branch_ids_ary and (not(at_branch_ids_ary.empty?)))
    all_loans = Lending.all(query)
    # TODO: must be changed for loan administration
    all_loans.group_by {|loan| loan.accounted_at_origin}
  end

  def individual_loans_by_centers_for_status_on_date(for_status, on_date, *at_center_ids_ary)
    loan_status, date_to_query, ignore_val = LoanLifeCycle::STATUSES_DATES_SUM_AMOUNTS[for_status]
    query = {:status => loan_status, date_to_query => on_date}
    query[:administered_at_origin] = at_center_ids_ary if (at_center_ids_ary and (not(at_center_ids_ary.empty?)))
    all_loans = Lending.all(query)
    # TODO: must be changed for loan administration
    all_loans.group_by {|loan| loan.administered_at_origin}
  end

  def aggregate_loans_by_branches_for_status_on_date(for_status, on_date, *at_branch_ids_ary)
    loan_status, date_to_query, amount_to_sum = LoanLifeCycle::STATUSES_DATES_SUM_AMOUNTS[for_status]
    query = {:status => loan_status, date_to_query => on_date}
    query[:accounted_at_origin] = at_branch_ids_ary if (at_branch_ids_ary and (not (at_branch_ids_ary.empty?)))
    query_results = Lending.all(query)

    count = query_results.count
    sum_amount = query_results.aggregate(amount_to_sum)
    sum_money_amount = sum_amount ? to_money_amount(sum_amount) : zero_money_amount
    {:count => count, :total_amount => sum_money_amount}
  end

  #this is the main query method to find out aggregate of loans by branches for various statuses in a date range.
  def aggregate_loans_by_branches_for_status_during_a_date_range(for_status, on_date, till_date, *at_branch_ids_ary)
    from_date, to_date = Constants::Time.ordered_dates(on_date, till_date)
    loan_status, date_to_query, amount_to_sum = LoanLifeCycle::STATUSES_DATES_SUM_AMOUNTS[for_status]
    query = {:status => loan_status, date_to_query.gte => from_date, date_to_query.lte => to_date}
    query[:accounted_at_origin] = at_branch_ids_ary if (at_branch_ids_ary and (not (at_branch_ids_ary.empty?)))
    query_results = Lending.all(query)

    count = query_results.count
    sum_amount = query_results.aggregate(amount_to_sum)
    sum_money_amount = sum_amount ? to_money_amount(sum_amount) : zero_money_amount
    {:count => count, :total_amount => sum_money_amount}
  end

  def aggregate_loans_by_branches_and_lending_products_for_status_on_date(for_status, on_date, lending_product_list, *at_branch_ids_ary)
    loan_status, date_to_query, amount_to_sum = LoanLifeCycle::STATUSES_DATES_SUM_AMOUNTS[for_status]
    query = {:status => loan_status, date_to_query => on_date, :lending_product_id => lending_product_list}
    query[:accounted_at_origin] = at_branch_ids_ary if (at_branch_ids_ary and (not (at_branch_ids_ary.empty?)))
    query_results = Lending.all(query)

    count = query_results.count
    sum_amount = query_results.aggregate(amount_to_sum)
    sum_money_amount = sum_amount ? to_money_amount(sum_amount) : zero_money_amount
    {:count => count, :total_amount => sum_money_amount}
  end

  def loans_by_centers_for_status_on_date(for_status, on_date, *at_center_ids_ary)
    loan_status, date_to_query, amount_to_sum = LoanLifeCycle::STATUSES_DATES_SUM_AMOUNTS[for_status]
    query = {:status => loan_status, date_to_query => on_date}
    query[:administered_at_origin] = at_center_ids_ary if (at_center_ids_ary and (not (at_center_ids_ary.empty?)))
    query_results = Lending.all(query)

    count = query_results.count
    sum_amount = query_results.aggregate(amount_to_sum)
    sum_money_amount = sum_amount ? to_money_amount(sum_amount) : zero_money_amount
    {:count => count, :total_amount => sum_money_amount}
  end

  def total_loan_allocation_receipts_at_locations_on_value_date(on_date, performed_or_accounted_choice, *at_location_ids_ary)
    total_loan_allocation_receipts_grouped_by_location = {}
    property_sym = TRANSACTION_LOCATIONS[performed_or_accounted_choice]
    at_location_ids_ary.each { |at_location_id|
      params = {:effective_on => on_date, property_sym => at_location_id, :loan_recovery => 0, :"lending.status.not" => :repaid_loan_status}
      all_loan_receipts_at_location = LoanReceipt.all(params)
      total_loan_allocation_receipts_grouped_by_location[at_location_id] = LoanReceipt.add_up(all_loan_receipts_at_location)
    }
    total_loan_allocation_receipts_grouped_by_location
  end

  #this method is to find out total loan allocation receipts at locations in a specified date range.
  def total_loan_allocation_receipts_at_locations_for_date_range(on_date, till_date, performed_or_accounted_choice, *at_location_ids_ary)
    total_loan_allocation_receipts_grouped_by_location = {}
    property_sym = TRANSACTION_LOCATIONS[performed_or_accounted_choice]
    at_location_ids_ary.each { |at_location_id|
      params = {:effective_on.gte => on_date, :effective_on.lte => till_date, property_sym => at_location_id, :loan_recovery => 0, :"lending.status.not" => :repaid_loan_status}
      all_loan_receipts_at_location = LoanReceipt.all(params)
      total_loan_allocation_receipts_grouped_by_location[at_location_id] = LoanReceipt.add_up(all_loan_receipts_at_location)
    }
    total_loan_allocation_receipts_grouped_by_location
  end

  def all_outstanding_loans_balances_at_locations_on_date(on_date, accounted_or_administered_choice, *at_location_ids_ary)
    location_ids_array = *at_location_ids_ary.to_a
    all_loan_balances_grouped_by_location = {}
    all_loans_grouped_by_location = all_outstanding_loan_ids_at_locations_on_date(on_date, accounted_or_administered_choice, *at_location_ids_ary)
    all_loans_grouped_by_location.each { |at_location_id, for_loan_ids_ary|
      all_loan_balances_grouped_by_location[at_location_id] = loan_balances_for_loan_ids_on_date(on_date, for_loan_ids_ary)
    }
    all_loan_balances_grouped_by_location
  end

  #main query to get outstanding loan_balances at locations for a date range.
  def all_outstanding_loans_balances_at_locations_for_date_range(on_date, till_date, accounted_or_administered_choice, *at_location_ids_ary)
    location_ids_array = *at_location_ids_ary.to_a
    all_loan_balances_grouped_by_location = {}
    all_loans_grouped_by_location = all_outstanding_loan_ids_at_locations_for_date_range(on_date, till_date, accounted_or_administered_choice, *at_location_ids_ary)
    for date in on_date..till_date
      all_loans_grouped_by_location.each { |at_location_id, for_loan_ids_ary|
        all_loan_balances_grouped_by_location[at_location_id] = loan_balances_for_loan_ids_for_date_range(date, for_loan_ids_ary)
      }
    end
    all_loan_balances_grouped_by_location
  end

  #method to get outstanding loan_ids for date range
  def all_outstanding_loan_ids_at_locations_for_date_range(on_date, till_date, accounted_or_administered_choice, *at_location_ids_ary)
    location_ids_array = *at_location_ids_ary.to_a
    all_loan_ids_grouped_by_location = {}
    location_ids_array.each { |at_location_id|
      all_loans_at_location = []
      all_outstanding_loans_at_location = []
      case accounted_or_administered_choice
      when Constants::Loan::ACCOUNTED_AT then all_loans_at_location = LoanAdministration.get_loans_accounted_for_date_range(at_location_id, on_date, till_date)
      when Constants::Loan::ADMINISTERED_AT then all_loans_at_location = LoanAdministration.get_loans_administered_for_date_range(at_location_id, on_date, till_date)
      else raise ArgumentError, "Please specify whether loans accounted or loans administered are needed"
      end
      for date in on_date..till_date
        all_loans_at_location.each do |loan|
          next if loan.applied_on_date > date
          all_outstanding_loans_at_location.push(loan) if loan.is_outstanding_on_date?(date)
        end
      end
      all_loan_ids_grouped_by_location[at_location_id] = get_ids(all_outstanding_loans_at_location)
    }
    all_loan_ids_grouped_by_location
  end

  def all_outstanding_loan_ids_at_locations_on_date(on_date, accounted_or_administered_choice, *at_location_ids_ary)
    location_ids_array = *at_location_ids_ary.to_a
    all_loan_ids_grouped_by_location = {}
    location_ids_array.each { |at_location_id|
      all_loans_at_location = []
      case accounted_or_administered_choice
        when Constants::Loan::ACCOUNTED_AT then all_loans_at_location = LoanAdministration.get_loans_accounted(at_location_id, on_date)
        when Constants::Loan::ADMINISTERED_AT then all_loans_at_location = LoanAdministration.get_loans_administered(at_location_id, on_date)
        else raise ArgumentError, "Please specify whether loans accounted or loans administered are needed"
      end
      all_outstanding_loans_at_location = all_loans_at_location.select {|loan| loan.is_outstanding_on_date?(on_date)}
      all_loan_ids_grouped_by_location[at_location_id] = get_ids(all_outstanding_loans_at_location)
    }
    all_loan_ids_grouped_by_location
  end

  def to_money_amount(amount)
    Money.new(amount.to_i, default_currency)
  end

  def zero_money_amount
    @zero_money_amount ||= MoneyManager.default_zero_money
  end

  def default_currency
    @default_currency ||= MoneyManager.get_default_currency
  end

  def loan_facade
    @loan_facade ||= FacadeFactory.instance.get_other_facade(FacadeFactory::LOAN_FACADE, self)
  end

  def location_facade
    @location_facade ||= FacadeFactory.instance.get_other_facade(FacadeFactory::LOCATION_FACADE, self)
  end

  def configuration_facade
    @configuration_facade ||= FacadeFactory.instance.get_other_facade(FacadeFactory::CONFIGURATION_FACADE, self)
  end

  def get_ids(collection)
    raise ArgumentError, "Collection does not appear to be enumerable" unless collection.is_a?(Enumerable)
    collection.collect {|element| element.id}
  end

end
