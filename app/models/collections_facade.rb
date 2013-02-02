# This facade serves functionality from the collections sub-system
class CollectionsFacade < StandardFacade

  # This returns instances of CollectionSheet which represent
  # the collection sheet at a center location on a given date
  #following function will generte the weeksheet for center.
  def get_collection_sheet(at_biz_location, on_date, only_installment_date = false)
    collection_sheet_line = []
    client_non_loan       = []
    on_date = on_date.class == Date ? on_date : Date.parse(on_date)
    biz_location    = BizLocation.get(at_biz_location)
    location_manage = LocationManagement.staff_managing_location(biz_location.id, on_date ) # Use this center_manager for staff ID, staff name
    center_manager  = location_manage.manager_staff_member unless location_manage.blank?
    manager_name    = center_manager.blank? ? 'No Manage' : center_manager.name
    manager_id      = center_manager.blank? ? '' : center_manager.id

    loan_ids = LoanAdministration.get_loan_ids_administered_by_sql(biz_location.id, on_date, false, LoanLifeCycle::DISBURSED_LOAN_STATUS)
    return [] if loan_ids.blank?

    #    loans           = loans.select{|loan| loan.status == LoanLifeCycle::DISBURSED_LOAN_STATUS}
    loan_ids        = BaseScheduleLineItem.all('loan_base_schedule.lending_id' => loan_ids, :on_date => on_date).loan_base_schedule.aggregate(:lending_id) if only_installment_date rescue []
    meeting_date    = meeting_facade.get_meeting(biz_location, on_date)
    meeting_hours   = meeting_date.blank? ? '00' : meeting_date.meeting_time_begins_hours
    meeting_minutes = meeting_date.blank? ? '00' : meeting_date.meeting_time_begins_minutes
    clients         = ClientAdministration.get_clients_administered_by_sql(biz_location.id, on_date)
    return [] if clients.blank?
    
    clients.each do |client|
      client_loans = LoanBorrower.all(:counterparty_id => client.id, :counterparty_type => 'client', 'lending.id' => loan_ids).lending
      #      client_loans = loans.select{|l| l.loan_borrower.counterparty == client}
      if client_loans.blank?
        client_non_loan << client.id
      else
        client_loans.each do |client_loan|
          loan_schedule_items                = loan_facade.previous_and_current_amortization_items(client_loan.id, on_date)
          client_name                        = client.name
          client_id                          = client.id
          client_group_id                    = client.client_group ? client.client_group.id : ''
          client_group_name                  = client.client_group ? client.client_group.name : "Not attached to any group"
          loan_id                            = client_loan.id
          loan_lan_no                        = client_loan.lan
          loan_amount                        = client_loan.total_loan_disbursed
          loan_status                        = client_loan.current_loan_status
          loan_disbursal_date                = client_loan.disbursal_date
          loan_due_status                    = client_loan.current_due_status
          loan_days_past_due                 = ''
          loan_schedule_status               = '' #TODO
          #loan_days_past_due                = loan_facade.get_days_past_due_on_date(client_loan.id, on_date) || 0
          loan_principal_due                 = ''
          loan_schedule_items                = loan_schedule_items.compact if loan_schedule_items.class == Array
          if loan_schedule_items.size > 1
            if loan_due_status == :overdue
              loan_schedule_item = loan_schedule_items.first.first
            else
              loan_schedule_item = loan_schedule_items.last.first
            end
          else
            loan_schedule_item = loan_schedule_items.class == Array ? loan_schedule_items.first.first : loan_schedule_items.first
          end
          loan_schedule_date                  = loan_schedule_item.first.last
          loan_schedule_on_date               = client_loan.loan_base_schedule.get_schedule_line_item(loan_schedule_date)
          loan_origin_schedule_date           = loan_schedule_on_date.blank? ? '' : loan_schedule_on_date.actual_date
          loan_schedule_installment_no        = loan_schedule_item.first.first
          loan_schedule_principal_due         = loan_schedule_item.last[:scheduled_principal_due]
          loan_actual_principal_outstanding   = client_loan.actual_principal_outstanding
          loan_schedule_principal_outstanding = loan_schedule_item.last[:scheduled_principal_outstanding]

          loan_schedule_interest_due          = loan_schedule_item.last[:scheduled_interest_due]
          loan_actual_total_due               = client_loan.actual_total_due(loan_schedule_date)
          loan_actual_interest_outstanding    = client_loan.actual_interest_outstanding
          loan_schedule_interest_outstanding  = loan_schedule_item.last[:scheduled_interest_outstanding]

          loan_advance_amount                 = client_loan.current_advance_available

          loan_principal_receipts             = loan_facade.principal_received_on_date(client_loan.id, on_date)
          loan_interest_receipts              = loan_facade.interest_received_on_date(client_loan.id, on_date)
          loan_advance_receipts               = loan_facade.advance_received_on_date(client_loan.id, on_date)

          loan_total_interest_due             = ''
          loan_total_principal_due            = ''
          
          collection_sheet_line << CollectionSheetLineItem.new(at_biz_location, biz_location.name, on_date, client_id, client_name, client_group_id,
            client_group_name, loan_id, loan_amount,
            loan_status, loan_disbursal_date, loan_due_status, loan_schedule_installment_no, loan_schedule_date, loan_origin_schedule_date, loan_days_past_due, loan_principal_due,
            loan_schedule_principal_due, loan_schedule_principal_outstanding, loan_schedule_interest_due, loan_schedule_interest_outstanding,
            loan_advance_amount, loan_principal_receipts, loan_interest_receipts, loan_advance_receipts,
            loan_total_principal_due, loan_total_interest_due, 
            loan_actual_principal_outstanding, loan_actual_interest_outstanding, loan_actual_total_due, loan_lan_no)
        end
      end
    end
    groups = collection_sheet_line.group_by{|x| [x.borrower_group_id, x.borrower_group_name]}.map{|c| c[0]}.sort_by { |obj| obj[1] }
    CollectionSheet.new(biz_location.id, biz_location.name, on_date, meeting_hours, meeting_minutes, manager_id, manager_name, collection_sheet_line, groups)
  end

  #following function will generate the daily collection sheet for staff_member.
  def get_collection_sheet_for_staff(staff_id, on_date, only_on_date = false, page = nil, limit = nil)
    collection_sheet = []
    staff = StaffMember.get staff_id

    #Find all centers by loan history on particular date
    location_manage = LocationManagement.locations_managed_by_staff(staff.id, on_date)
    biz_locations = location_manage.blank? ? [] : location_manage.collect{|lm| lm.managed_location}
    locations = page.blank? ? biz_locations.flatten.uniq : BizLocation.all(:id => biz_locations.flatten.uniq.map(&:id)).paginate(:page => page, :per_page => limit)
    count = 0
    locations.each do |biz_location|
      cs = self.get_collection_sheet(biz_location.id, on_date, only_on_date)
      unless cs.blank?
        collection_sheet << cs
        count = count + 1
      end
      break if count > 3
    end
    page.blank? ? collection_sheet : [biz_locations.flatten.uniq.paginate(:page => page, :per_page => limit), collection_sheet]
  end

  #following function will generate the daily collection sheet for staff_member.
  def get_all_collection_sheet_for_staff(staff_id, on_date, branch = nil, page = nil, limit = nil)
    collection_sheet = []
    staff            = StaffMember.get staff_id
    zero_amt         = MoneyManager.default_zero_money

    #Find all centers by loan history on particular date
    centers = branch.blank? ? [] : LocationLink.get_children_ids_by_sql(branch, on_date)
    managed_location_ids = LocationManagement.location_ids_managed_by_staff_by_sql(staff.id, on_date)
    location_ids         = managed_location_ids.blank? ? [] : Lending.all('loan_base_schedule.base_schedule_line_items.on_date' => on_date, :status => LoanLifeCycle::DISBURSED_LOAN_STATUS, :administered_at_origin => managed_location_ids).aggregate(:administered_at_origin)
    if location_ids.blank?
      biz_locations = []
    else
      location_ids = centers & location_ids unless branch.blank?
      biz_locations = page.blank? ? BizLocation.all(:id => location_ids) : BizLocation.all(:id => location_ids).paginate(:page => page, :per_page => limit) 
    end
    biz_locations.each do |biz_location|
      collection_sheet_line                = []
      loan_ids                             = LoanAdministration.get_loan_ids_administered_by_sql(biz_location.id, on_date, false, LoanLifeCycle::DISBURSED_LOAN_STATUS).compact
      all_schedules                        = loan_ids.blank? ? [] : BaseScheduleLineItem.all('loan_base_schedule.lending_id' => loan_ids)
      loans_receipts                       = loan_ids.blank? ? [] : LoanReceipt.all(:lending_id => loan_ids)
      schedules_on_date                    = all_schedules.select{|s| s.on_date == on_date}
      schedules_on_date.each do |schedule|
        loan                               = schedule.loan_base_schedule.lending
        loan_schedule_till_date            = all_schedules.select{|s| s.loan_base_schedule.lending_id == loan.id && s.on_date <= schedule.on_date}
        loan_receipt_on_date               = loans_receipts.select{|rl| rl.lending_id == loan.id && rl.effective_on == schedule.on_date}
        loan_receipt_till_date             = loans_receipts.select{|rl| rl.lending_id == loan.id && rl.effective_on <= schedule.on_date}
        loan_receipt_on_date_amt           = LoanReceipt.add_up(loan_receipt_on_date)
        loan_receipt_till_date_amt         = LoanReceipt.add_up(loan_receipt_till_date)
        client                             = loan.loan_borrower.counterparty
        client_name                        = client.name
        client_id                          = client.id
        client_group_id                    = client.client_group ? client.client_group.id : ''
        client_group_name                  = client.client_group ? client.client_group.name : "Not attached to any group"
        loan_id                            = loan.id
        loan_lan_no                        = loan.lan
        loan_disbursed_principal           = loan.to_money[:disbursed_amount]
        loan_disbursed_interest            = loan.loan_base_schedule.to_money[:total_interest_applicable]
        loan_status                        = loan.status
        loan_disbursal_date                = loan.disbursal_date
        scheduled_installment_no           = schedule.installment
        scheduled_installment_date         = schedule.on_date
        schedule_principal_till_date       = loan_schedule_till_date.blank? ? MoneyManager.default_zero_money : MoneyManager.get_money_instance_least_terms(loan_schedule_till_date.map(&:scheduled_principal_due).sum.to_i)
        schedule_interest_till_date        = loan_schedule_till_date.blank? ? MoneyManager.default_zero_money : MoneyManager.get_money_instance_least_terms(loan_schedule_till_date.map(&:scheduled_interest_due).sum.to_i)
        principal_received_till_date       = loan_receipt_till_date_amt[:principal_received]
        interest_received_till_date        = loan_receipt_till_date_amt[:interest_received]
        advance_received_till_date         = loan_receipt_till_date_amt[:advance_received]
        advance_adjust_till_date           = loan_receipt_till_date_amt[:advance_adjusted]
        advance_balance_till_date          = advance_received_till_date > advance_adjust_till_date ? advance_received_till_date - advance_adjust_till_date : MoneyManager.default_zero_money
        scheduled_principal_due            = schedule.to_money[:scheduled_principal_due]
        scheduled_interest_due             = schedule.to_money[:scheduled_interest_due]
        actual_principal_outstanding       = loan_disbursed_principal > principal_received_till_date ? loan_disbursed_principal - principal_received_till_date : MoneyManager.default_zero_money
        actual_interest_outstanding        = loan_disbursed_interest > interest_received_till_date ? loan_disbursed_interest - interest_received_till_date : MoneyManager.default_zero_money

        total_actual_outstanding           = actual_principal_outstanding + actual_interest_outstanding
        principal_received                 = loan_receipt_on_date_amt[:principal_received]
        interest_received                  = loan_receipt_on_date_amt[:interest_received]
        advance_received                   = loan_receipt_on_date_amt[:advance_received]

        principal_overdue                  = schedule_principal_till_date > principal_received_till_date ? schedule_principal_till_date - principal_received_till_date : MoneyManager.default_zero_money
        interest_overdue                   = schedule_interest_till_date > interest_received_till_date ? schedule_interest_till_date - interest_received_till_date : MoneyManager.default_zero_money
        principal_overdue_on_date          = principal_overdue >= scheduled_principal_due ? principal_overdue - scheduled_principal_due : principal_overdue
        interest_overdue_on_date           = interest_overdue >= scheduled_interest_due ? interest_overdue - scheduled_interest_due : interest_overdue
        loan_due_status                    = principal_overdue > zero_amt || interest_overdue > zero_amt ? 'Overdue' : 'Due'
        collection_sheet_line << CollectionSheetLineItem.new(biz_location.id, biz_location.name, on_date, client_id, client_name, client_group_id,
          client_group_name, loan_id, loan_disbursed_principal,
          loan_status, loan_disbursal_date, loan_due_status, scheduled_installment_no, scheduled_installment_date, schedule.actual_date, '', MoneyManager.default_zero_money,
          scheduled_principal_due, schedule[:scheduled_principal_outstanding], scheduled_interest_due, schedule[:scheduled_interest_outstanding],
          advance_balance_till_date, principal_received, interest_received, advance_received,
          MoneyManager.default_zero_money, MoneyManager.default_zero_money,
          actual_principal_outstanding, actual_interest_outstanding, total_actual_outstanding,loan_lan_no,
          principal_overdue_on_date, interest_overdue_on_date)
      end
      unless collection_sheet_line.blank?
        groups = collection_sheet_line.group_by{|x| [x.borrower_group_id, x.borrower_group_name]}.map{|c| c[0]}.sort_by { |obj| obj[1] }
        collection_sheet << CollectionSheet.new(biz_location.id, biz_location.name, on_date, '', '', '', '', collection_sheet_line, groups)
      end
    end
    page.blank? ? [location_ids, collection_sheet] : [location_ids.paginate(:page => page, :per_page => limit), collection_sheet]
  end

  private

  def loan_facade
    @loan_facade ||= FacadeFactory.instance.get_other_facade(FacadeFactory::LOAN_FACADE, self)
  end

  def location_facade
    @location_facade ||= FacadeFactory.instance.get_other_facade(FacadeFactory::LOCATION_FACADE, self)
  end

  def meeting_facade
    @meeting_facade ||= FacadeFactory.instance.get_other_facade(FacadeFactory::MEETING_FACADE, self)
  end
end
