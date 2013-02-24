class BizLocation
  include DataMapper::Resource
  include Identified
  include Pdf::LoanSchedule if PDF_WRITER
  
  property :id,                       Serial
  property :biz_location_identifier,  String,           :nullable => true
  property :name,                     String,           :nullable => false
  property :created_at,               DateTime,         :nullable => false, :default => DateTime.now
  property :creation_date,            Date,             :nullable => false, :default => Date.today
  property :deleted_at,               ParanoidDateTime
  property :center_disbursal_date,    Date,             :nullable => true,  :default => Date.today
  property :biz_location_address,     String,           :nullable => true
  property :originator_by,            Integer

  belongs_to :location_level
  belongs_to :upload, :nullable => true
  
  has n, :meeting_schedules, :through => Resource
  has 1, :address
  has n, :permitted_pin_codes, 'AddressPinCode'
  has n, :holiday_administrations
  has n, :location_holidays, :through => :holiday_administrations
  has 1, :cost_center

  has n, :origin_home_staff, :model => 'StaffMember', :child_key => [:origin_home_location_id]
  has n, :visit_schedules
  has n, :client_groups
  has n, :bank_branches
  has n, :eod_processes
  has n, :bod_processes
  has n, :accounting_locations
  has n, :lending_product_locations
  has n, :lending_products, :through => :lending_product_locations
  has n, :center_cycles
  has n, :pachecklists
  has n, :surprise_visit_centers
 
  #validation to be disabled in migration mode.
  if Mfi.first.system_state != :migration
    validates_with_method :location_level_precedes_biz_location?
  end

  validates_is_unique :name
  validates_present :name

  def self.from_csv(row, headers)
    location_level = LocationLevel.first(:name => row[headers[:location_level_name]])    
    raise ArgumentError, "Location Level(#{row[headers[:location_level_name]]}) does not exist" if location_level.blank?
    location_level_number = location_level.level
    if location_level.level == 0
      center_disbursal_date = Date.parse(row[headers[:center_disbursal_date]])
    else
      center_disbursal_date = Date.today
    end

    originator_by = StaffMember.first(:name => row[headers[:originated_by]]).id
    creation_date = Date.parse(row[headers[:creation_date]])
    name = row[headers[:name]]
    upload_id = row[headers[:upload_id]]
    address = row[headers[:address]]

    location = {}
    location[:name] = name
    location[:creation_date] = creation_date
    location[:location_level] = location_level
    location[:originator_by] = originator_by
    location[:biz_location_address] = address
    location[:center_disbursal_date] = center_disbursal_date
    obj = create(location)
    if obj.save
      #setiing up the chart of accounts if location_level is 1, i.e., branch. and assigning the locations.
      Ledger.setup_location_ledgers(obj.creation_date, obj.id) if obj.location_level.level == 1
      parent_location_level = LocationLevel.first(:level => obj.location_level.level+1)
      unless parent_location_level.blank?
        parent_location = parent_location_level.biz_locations.first(:name => row[headers[:parent_location]])
        LocationLink.assign(obj, parent_location, row[headers[:effective_date]]) unless parent_location.blank?
      end

      #assigning staff to locations.
      staff = StaffMember.first(:name => row[headers[:manager]])
      raise ArgumentError, "Staff Member(#{row[headers[:manager]]}) does not exist" if staff.blank?
      LocationManagement.assign_manager_to_location(staff, obj, creation_date, User.first.staff_member.id, User.first.id)

      if obj.location_level.level == 0
        #creating center cycle for center.
        obj.center_cycles.create(:cycle_number => 1, :initiated_by_staff_id => User.first.staff_member.id, :initiated_on => Date.today,
          :status => Constants::Space::OPEN_CENTER_CYCLE_STATUS, :created_by => User.first.staff_member.id)
      end
      [true, obj]
    else
      [false, obj]
    end
  end

  def location_level_precedes_biz_location?
    Validators::Assignments.is_valid_assignment_date?(self.creation_date, self, self.location_level)
  end

  def self.get_state_locations
    all('location_level.name' => 'state')
  end

  def get_parent_location_at_location_level(location_level_name)
    LocationLink.all_parents(self).select{|l| l.location_level.name.downcase == location_level_name.downcase}.first
  end

  def created_on; creation_date; end

  def address_text
    address ? address.full_address_text : "NOT SPECIFIED"
  end

  def all_pin_codes
    own_address_pin_code_ary = address ? [address.address_pin_code] : nil
    own_address_pin_code_ary ? (own_address_pin_code_ary + self.permitted_pin_codes).flatten.uniq : self.permitted_pin_codes
  end

  def level_number
    self.location_level.level
  end

  def is_nominal_branch?
    self.level_number == LocationLevel::NOMINAL_BRANCH_LEVEL
  end

  def is_nominal_center?
    self.level_number == LocationLevel::NOMINAL_CENTER_LEVEL
  end

  # Returns all locations that belong to LocationLevel
  def self.all_locations_at_level(by_level_number)
    all('location_level.level' => by_level_number)
  end

  # Create a new location by specifying the name, the creation date, and the level number (not the level)
  def self.create_new_location(by_name, on_creation_date, at_level_number, originator_by, address = nil, default_disbursal_date = nil)
    raise ArgumentError, "Level numbers begin with zero" if (at_level_number < 0)
    level = LocationLevel.get_level_by_number(at_level_number)
    raise Errors::InvalidConfigurationError, "No level was located for the level number: #{at_level_number}" unless level
    location = {}
    location[:name] = by_name
    location[:creation_date] = on_creation_date
    location[:location_level] = level
    location[:originator_by] = originator_by unless originator_by.blank?
    location[:biz_location_address] = address unless address.blank?
    location[:center_disbursal_date] = default_disbursal_date unless default_disbursal_date.blank?
    location[:biz_location_identifier] = at_level_number == 1 ? get_branch_identifier : nil
    new_location = create(location)
    raise Errors::DataError, new_location.errors.first.first unless new_location.saved?
    Ledger.setup_location_ledgers(new_location.creation_date, new_location.id) if new_location.location_level.level == 1
    new_location
  end

  # Gets the name of the LocationLevel that this location belongs to
  def level_name
    self.location_level and self.location_level.name ? self.location_level.name : nil
  end

  # Prints the level name, the name, and the ID
  def to_s
    "#{self.level_name ? self.level_name + " " : ""}#{self.name_and_id}"
  end

  def meeting_schedule_effective(on_date)
    query = {}
    query[:schedule_begins_on.lte] = on_date
    query[:order] = [:schedule_begins_on.desc]
    self.meeting_schedules.first(query)
  end

  def save_meeting_schedule(meeting_schedule)
    self.meeting_schedules << meeting_schedule
    save
  end

  def self.search(q, per_page=10)
    if /^\d+$/.match(q)
      BizLocation.all(:conditions => {:id => q}, :limit => per_page)
    else
      BizLocation.all(:conditions => ["name=? or name like ?", q,"#{q}%"], :limit => per_page)
    end
  end

  def self.map_by_level(*locations)
    raise ArgumentError, "#{locations} are not valid arguments" unless (locations and locations.is_a?(Array) and (not (locations.empty?)))
    location_map = {}
    locations.flatten!
    return location_map if locations.empty?
    locations.each {|biz_location|
      level = biz_location.location_level
      level_list = location_map[level] ||= []
      level_list.push(biz_location)
      location_map[level] = level_list
    }
    location_map
  end

  def business_eod_on_date(on_date = Date.today)
    eod = {:business_eod => {}, :collection_eod => {}}
    total_disbursment = MoneyManager.default_zero_money
    center_locations = []
    total_clients = []
    absent_clients = []
    attendance_record = []
    abs_in_presentage = 0
    collectable_amt = MoneyManager.default_zero_money
    collected_amt = MoneyManager.default_zero_money
    collected_in_persentage = 0
    overdue_amt = MoneyManager.default_zero_money
    dis_locations = 0
    clients = 0
    cgt1_members = []
    cgt2_members = []
    grt_centers = []
    grt_members = []
    apo_members = []
    hm_approve = []
    ops_centers = []
    ops_members = []
    user = User.first
    locations = self.location_level.level == 0 ? [self] : LocationLink.all_children_by_sql(self, on_date)
    center_locations = locations.blank? ? [] : locations.select{|l| l.location_level.level == 0}
    repayments = center_locations.blank? ? [] : PaymentTransaction.all(:effective_on => on_date, :on_product_type => :lending, :payment_towards => :payment_towards_loan_disbursement, :performed_at => center_locations.map(&:id))
    unless repayments.blank?
      total_disbursment = repayments.map(&:payment_money_amount).sum
      dis_locations = repayments.map(&:performed_at).uniq.count
      clients = repayments.map(&:by_counterparty_id).uniq.count
    end
    center_locations.each do |center|
      center_cycle = CenterCycle.first(:biz_location_id => center.id, :created_at.lte => on_date, :order => [:cycle_number.desc])
      unless center_cycle.blank?
        cgt1_members << center_cycle.loan_applications if center_cycle.cgt_date_one == on_date
        cgt2_members << center_cycle.loan_applications if center_cycle.cgt_date_two == on_date
        grt_members << center_cycle.loan_applications if center_cycle.grt_completed_on == on_date
        grt_centers << center if center_cycle.grt_completed_on == on_date
      end
    end
    total_clients = ClientAdministration.get_client_ids_registered_by_sql(self.id, on_date)
    attendance_record = AttendanceRecord.get_client_attendance_at_location(center_locations.map(&:id), on_date)
    payment_collection = get_reporting_facade(user).total_dues_collected_and_collectable_per_location_on_date(self.id, on_date)
    collectable_amt += payment_collection[:scheduled_total]
    collected_amt += payment_collection[:scheduled_total_collected]
    overdue_amt += payment_collection[:overdue_amt]
    total_clients = total_clients.flatten.uniq.count
    attendance_record = attendance_record.flatten.uniq
    absent_clients = attendance_record.select{|s| s.attendance != Constants::User::PRESENT_ATTENDANCE_STATUS }.count
    abs_in_presentage = (absent_clients/total_clients)*100 if total_clients > 0 && attendance_record.count > 0
    collected_in_persentage = (collected_amt.amount.to_i/collectable_amt.amount.to_i)*100 if collectable_amt > MoneyManager.default_zero_money
    eod[:collection_eod] = {:total_centers => center_locations.flatten.uniq.count, :total_clients => total_clients, :client_absent => absent_clients,
      :client_absent_in_presentage => "#{abs_in_presentage}%", :collectable_amt => collectable_amt, :collected_amt => collected_amt,
      :collected_in_presentage => "#{collected_in_persentage}%", :overdue_amt => overdue_amt
    }
    eod[:business_eod] = {:total_disbursment => total_disbursment, :disbursment_locations => dis_locations, :disbursment_clients => clients,
      :hm_approve => hm_approve.uniq.count, :apo_members => apo_members.uniq.count, :cgt1_members => cgt1_members.uniq.count,
      :cgt2_members => cgt2_members.uniq.count, :grt_members => grt_members.uniq.count, :grt_centers => grt_centers.uniq.count,
      :ops_centers => ops_centers.uniq.count, :ops_members => ops_members.uniq.count}
    eod
  end

  def location_eod_summary(user, on_date = Date.today)
    location_ids = self.location_level.level == LocationLevel::NOMINAL_BRANCH_LEVEL ? [self.id] : LocationLink.get_children(self, on_date).map(&:id)
    reporting_facade = FacadeFactory.instance.get_instance(FacadeFactory::REPORTING_FACADE, user)
    total_new_loan_application       = ''
    loans_pending_approval           = reporting_facade.loans_applied_by_branches_on_date(on_date, *location_ids)
    loans_approved_today             = reporting_facade.loans_approved_by_branches_on_date(on_date, *location_ids)
    loans_scheduled_for_disbursement = reporting_facade.loans_scheduled_for_disbursement_by_branches_on_date(on_date, *location_ids)
    loans_disbursed_today            = reporting_facade.loans_disbursed_by_branches_on_date(on_date, *location_ids)
    t_fee_collect                    = reporting_facade.all_aggregate_fee_receipts_by_branches(on_date, on_date, *location_ids)
    advance_values                   = reporting_facade.sum_all_outstanding_loans_balances_accounted_at_locations_on_date(on_date, *location_ids)
    #t_advance_adjusted               = advance_values[]

    t_repayment_due                  = reporting_facade.loans_scheduled_for_disbursement_by_branches_on_date(on_date, *location_ids)
    t_repayment_received             = reporting_facade.all_receipts_on_loans_accounted_at_locations_on_value_date(on_date, *location_ids)
    t_outstanding                    = reporting_facade.all_outstanding_loans_balances_accounted_at_locations_on_date(on_date, *location_ids)

    t_money_deposits_recorded_today       = reporting_facade.total_money_deposited_on_date_at_locations(on_date, *location_ids)
    t_money_deposits_verified_confirmed   = reporting_facade.total_money_deposited_verified_confirmed_on_date_at_locations(on_date, *location_ids)
    t_money_deposits_verified_rejected    = reporting_facade.total_money_deposited_verified_rejected_on_date_at_locations(on_date, *location_ids)
    t_money_deposits_pending_verification = reporting_facade.total_money_deposited_pending_verification_until_date_at_locations(on_date, *location_ids)

    EodSummary.new(total_new_loan_application, loans_pending_approval, loans_approved_today, loans_scheduled_for_disbursement, loans_disbursed_today,
      t_repayment_due, t_repayment_received, t_outstanding, t_money_deposits_recorded_today, t_money_deposits_verified_confirmed,
      t_money_deposits_verified_rejected,t_money_deposits_pending_verification).summary
  end

  #################
  # Search Begins #
  #################

  def self.search(q, per_page)
    if /^\d+$/.match(q)
      BizLocation.all(:conditions => {:id => q}, :limit => per_page)
    else
      BizLocation.all(:conditions => ["name=? or name like ? or biz_location_identifier like ?", q, q+'%',q+'%'], :limit => per_page)
    end
  end

  ###############
  # Search Ends #
  ###############

  def get_reporting_facade(user)
    @reporting_facade ||= FacadeFactory.instance.get_instance(FacadeFactory::REPORTING_FACADE, user)
  end

  # list loan amount of all loan product associated with branch
  def branch_loan_product_amount_list
    loan_product_amount = []
    loan_product_list = self.lending_product_locations
    loan_product_list.each do |lpc|
      loan_product_id = lpc.lending_product_id
      loan_product = LendingProduct.get loan_product_id
      loan_product_amount << loan_product.loan_money_amount.to_regular_amount
    end
    loan_product_amount.compact.uniq
  end

  # list loan product of same frequency as per center creation frequency set
  def same_frequency_branch_loan_product(center)
    center_frequency = center.meeting_schedules.first.meeting_frequency rescue nil
    loan_product_amount = []
    loan_product_list = self.lending_products.all(:repayment_frequency => center_frequency)
    return [] if loan_product_list.blank?
    loan_product_list.each do |loan_product|
      loan_product_amount << loan_product.loan_money_amount.to_regular_amount
    end
    loan_product_amount.compact.uniq
  end

  # list loan product names of same frequency as per center creation frequency set
  def same_frequency_branch_loan_product_name_list(center)
    center_frequency = center.meeting_schedules.first.meeting_frequency rescue nil
    loan_product_list = self.lending_products.all(:repayment_frequency => center_frequency)
    return [] if loan_product_list.blank?
    loan_product_list.compact.uniq
  end

  # returns repayment frequency of loan products assigned to branch
  def branch_loan_product_repayment_frequencies
    loan_product = []
    loan_product_list = self.lending_product_locations
    loan_product_list.each do |lpc|
      loan_product_id = lpc.lending_product_id
      loan_product << LendingProduct.get(loan_product_id)
    end
    loan_product.collect{|lp| lp.repayment_frequency}.uniq
  end

  # Generates biz-location identifier for branch with proper format:
  # Branch format: BR_0001
  def self.get_branch_identifier
    prefix = nil
    prefix, prefix_id = "BR-", 1
    if prefix.blank?
      nil
    else
      # Find last biz-location for location level branch
      last_biz_location = BizLocation.all('location_level.level' => prefix_id).last
      if last_biz_location.blank?
        prefix+"%.4i"%1
      else
        # Find last biz-locations identifier
        identifier = last_biz_location.biz_location_identifier
        # Find last biz-location identifiers id
        splited_identifier = identifier.split(prefix).last.to_i + 1
        # Incremented identifier with proper format
        prefix+"%.4i"%splited_identifier
      end
    end
  end

  # Generates biz-location identifier for Center with proper format:
  # Center format: CN_0001_0001
  def self.update_biz_location_identifier_for_center(biz_location, parent_location)
    center_prefix = "CN-"
    branch_prefix = "BR-"
    branch_identifier = parent_location.biz_location_identifier
    splited_branch_identifier = branch_identifier.split(branch_prefix).last
    parent_branch_last_center = LocationLink.get_children_by_sql(parent_location, Date.today).all(:biz_location_identifier.not=> nil).last
    if parent_branch_last_center.blank?
      center_identifier = center_prefix+splited_branch_identifier+"-"+"%.6i"%1
    else
      parent_branch_last_centers_identifier = parent_branch_last_center.biz_location_identifier
      last_centers_splited_identifier = parent_branch_last_centers_identifier.split("-").last.to_i + 1
      center_identifier = center_prefix+splited_branch_identifier+"-"+"%.6i"%last_centers_splited_identifier
    end
    biz_location.biz_location_identifier = center_identifier
    biz_location.save
  end

  def self.get_biz_location_identifier(biz_location_id)
    identifier = BizLocation.get(biz_location_id).biz_location_identifier
    identifier.split("-").last
  end

  def self.get_center_identifier_for_due_sheet(biz_location_id)
    identifier = BizLocation.get(biz_location_id).biz_location_identifier
    identifier.split("CN-").last
  end

  # for one time use only- to update existing data
  def self.update_biz_location_identifier_for_existing_branch
    prefix = "BR-"
    branch_code = 1
    all_branches = BizLocation.all_locations_at_level(LocationLevel::NOMINAL_BRANCH_LEVEL)
    all_branches.each do |b|
      b.biz_location_identifier = prefix+"%.4i"%branch_code
      branch_code += 1
      b.save!
    end
  end

  # for one time use only- to update existing data
  def self.update_biz_location_identifier_for_existing_center
    center_prefix = "CN-"
    branch_prefix = "BR-"
    all_branches = BizLocation.all_locations_at_level(LocationLevel::NOMINAL_BRANCH_LEVEL)
    all_branches.each do |b|
      center_code = 1
      branch_identifier = b.biz_location_identifier.split(branch_prefix).last
      all_centers = LocationLink.get_children_by_sql(b, Date.today)
      all_centers.each do |c|
        c.biz_location_identifier = center_prefix+branch_identifier+"-"+"%.6i"%center_code
        c.save!
        center_code += 1
      end
    end
  end

  def loans_advance_adjusted_on_date(on_date = Date.today)
    loans = LoanAdministration.get_loans_administered_by_sql(self.id, on_date, false, 'disbursed_loan_status')
    user = User.first
    loans.each do |loan|
      get_loan_facade(user).adjust_advance(on_date, loan.id) if loan.advance_balance(on_date) > loan.zero_money_amount && loan.schedule_date?(on_date)
    end
  end

  def get_loan_facade(user)
    @location_facade ||= FacadeFactory.instance.get_instance(FacadeFactory::LOAN_FACADE, user)
  end
  
end
