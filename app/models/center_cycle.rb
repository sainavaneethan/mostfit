class CenterCycle
  include DataMapper::Resource
  include Constants::Space
  include Constants::CenterFormation
  include Constants::Properties

  # In general, each center advances as a whole to a new cycle of loans
  # All activities to disburse new loans are within the 'scope' of this cycle
  # The cycle has a cycle number that identifies it
  # Cycle numbers are monotonically increasing integers starting at 1,
  # and bumped up by one, each time a new cycle is begun at a center
  
  property :id,                    Serial
  property :cycle_number,          Integer, :nullable => false
  property :biz_location_id,       Integer, :nullable => false
  property :initiated_by_staff_id, Integer, :nullable => false
  property :initiated_on,          Date, :nullable => false
  property :closed_by_staff_id,    Integer, :nullable => true
  property :closed_on,             Date, :nullable => true
  
  # for CGT at center for cycle
  property :cgt_date_one,          Date, :nullable => true
  property :cgt_date_two,          Date, :nullable => true
  property :cgt_performed_by_staff,Integer, :nullable => true #Staff Member ID
  property :cgt_recorded_by_user,  Integer, :nullable => true
  property :cgt_recorded_at,       DateTime, :nullable => true

  # GRT completion
  property :grt_status,            Enum.send('[]', *GRT_STATUSES), :nullable => false, :default => GRT_NOT_DONE
  property :grt_completed_by_staff,Integer, :nullable => true
  property :grt_completed_on,      Date, :nullable => true
  property :grt_recorded_by_user,  Integer, :nullable => true
  property :grt_recorded_at,       DateTime, :nullable => true
  property :is_restarted,          Boolean, :default => false

  property :status,                Enum.send('[]', *CENTER_CYCLE_STATUSES), :nullable => false, :default => OPEN_CENTER_CYCLE_STATUS
  property :created_by,            Integer, :nullable => false
  property :created_at,            *CREATED_AT
  property :updated_at,            DateTime, :nullable => false, :default => DateTime.now

  belongs_to :biz_location
  has n, :loan_applications

  #  validates_with_method :cycle_number, :method => :check_previous_center_cycle_closed?

  #  validates_with_method :cycle_number, :method => :is_cycle_incremented?
  #  validates_with_method :initiated_on, :method => :initiated_on_should_be_later_than_the_last_closed_on

  def self.create_center_cycle(initiated_on, center_id, created_by)
    center_cycle_hash = {}
    center_cycle_hash[:initiated_on] = initiated_on
    center_cycle_hash[:created_by] = created_by
    center_cycle_hash[:initiated_by_staff_id] = created_by
    center_cycle_hash[:created_at] = initiated_on
    center_cycle_hash[:biz_location_id] = center_id
    center_cycle = create(center_cycle_hash)
    raise Errors::DataError, center_cycle.errors.first.first unless center_cycle.saved?
  end

  def mark_GRT_status(with_status, by_staff, on_date, by_user)
    self.grt_status = with_status
    self.grt_completed_by_staff = by_staff
    self.grt_completed_on = on_date
    self.grt_recorded_by_user = by_user
    self.grt_recorded_at = DateTime.now
    save
  end

  #  # The cycle number can only be incremented by one each time
  #  def is_cycle_incremented?
  #    latest_cycle_number = CenterCycle.get_current_center_cycle(self.biz_location_id)
  #    previous_center_cycle = CenterCycle.get_cycle(self.biz_location_id, latest_cycle_number)
  #    return true if (previous_center_cycle && (self.id == previous_center_cycle.id))
  #    return [false, "The center cycle can only be advanced to #{(latest_cycle_number + 1)}"] if ((self.cycle_number - latest_cycle_number) != 1)
  #    return true
  #  end

  #  def initiated_on_should_be_later_than_the_last_closed_on
  #    previous_center_cycle = CenterCycle.get_cycle(self.biz_location_id, CenterCycle.get_current_center_cycle(self.biz_location_id))
  #    return true if (previous_center_cycle && (self.id == previous_center_cycle.id))
  #    return [false, "The previous center cycle has not been closed"] if (previous_center_cycle && previous_center_cycle.closed_on.nil?)
  #    return [false, "The current center cycle cannot be initiated before the last center cycle was closed"] if (previous_center_cycle && (self.initiated_on < previous_center_cycle.closed_on))
  #    return true
  #  end

  # it returns current cycle number of center
  def self.get_current_center_cycle_number(center_id)
    latest = last(:biz_location_id => center_id, :status => Constants::Space::OPEN_CENTER_CYCLE_STATUS, :closed_on => nil)
    latest.blank? ? 0 : latest.cycle_number
  end

  def self.get_current_center_cycle(center_id)
    last(:biz_location_id => center_id, :status => Constants::Space::OPEN_CENTER_CYCLE_STATUS, :closed_on => nil)
  end

  def self.get_cycle(for_center, by_cycle_number)
    first(:biz_location_id => for_center, :cycle_number => by_cycle_number, :order => [:cycle_number.desc])
  end

  # Encapsulates fetching the status of a center cycle
  def get_cycle_status
    self.status
  end

  # Test for whether this center cycle is still open
  def is_open?
    get_cycle_status == OPEN_CENTER_CYCLE_STATUS
  end

  # Test for whether this center cycle is closed, merely negates test for open
  def is_closed?
    not is_open?
  end

  # Mark the center cycle closed (in preparation for the next center cycle)
  def mark_cycle_closed(by_staff, on_date)
    raise ArgumentError, "cycle close date specified: #{on_date} cannot precede cycle open date #{self.initiated_on}" if (on_date < self.initiated_on)
    self.closed_by_staff_id = by_staff;
    self.closed_on = on_date
    self.status = CLOSED_CENTER_CYCLE_STATUS
    self.save
  end

  # Return true if GRT passed fo particular center
  def self.is_grt_marked?(center_id, for_cycle_number = 1)
    center_cycle = CenterCycle.first(:biz_location_id => center_id, :cycle_number => for_cycle_number)
    center_cycle.grt_status == Constants::CenterFormation::GRT_PASSED ? true : false
  end

  # Return center GRT Passed on date
  def self.center_grt_passed_on(center_id, for_cycle_number = 1)
    CenterCycle.first(:biz_location_id => center_id, :cycle_number => for_cycle_number).grt_completed_on rescue nil
  end

  # While creating center, center cycle with cycle number 1 is automatically gets created but
  # this association has been added at last, so this class method will create center cycle with cycle number 1 for existing centers
  def self.update_center_cycle_for_existing_centers
    all_centers = []
    BizLocation.all.each do |biz_location|
      all_centers << biz_location if biz_location.location_level.level == 0 && biz_location.center_cycles.blank?
    end
    all_centers.each do |center|
      center.center_cycles.create(:cycle_number => 1, :initiated_by_staff_id => User.first.staff_member.id, :initiated_on => center.creation_date, :status => Constants::Space::OPEN_CENTER_CYCLE_STATUS, :created_by => User.first.staff_member.id)
    end
  end

  private

  def check_previous_center_cycle_closed?
    center_cycle_status = biz_location.center_cycles.all.aggregate(:status)
    return center_cycle_status.include?("1") ? [false, "previous center cycle is not closed"] : true
  end

end