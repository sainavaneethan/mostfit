class StaffPosting
  include DataMapper::Resource
  include Constants::Properties
  include Comparable
  # Staff are assigned to different BizLocations at different points in time
  # via a StaffPosting

  property :id,             Serial
  property :staff_id,       *INTEGER_NOT_NULL
  property :at_location_id, *INTEGER_NOT_NULL
  property :effective_on,   *DATE_NOT_NULL
  property :performed_by,   *INTEGER_NOT_NULL
  property :recorded_by,    *INTEGER_NOT_NULL
  property :created_at,     *CREATED_AT
  property :reference,      Integer, :unique => true    #property added for upload functionality.

  belongs_to :upload, :nullable => true

  def staff_assigned; StaffMember.get(self.staff_id); end
  def assigned_to_location; BizLocation.get(self.at_location_id); end

  validates_with_method :only_one_posting_on_date?
  validates_with_method :assignment_and_creation_dates_are_valid?
  validates_with_method :staff_member_is_active?

  def only_one_posting_on_date?
    assigned_elsewhere_on_date = StaffPosting.first(:staff_id => self.staff_id, :effective_on => self.effective_on)
    assigned_elsewhere_on_date ? [false, "The staff member has already been assigned to another location on the same date"] :
        true
  end

  def assignment_and_creation_dates_are_valid?
    Validators::Assignments.is_valid_assignment_date?(effective_on, staff_assigned, assigned_to_location)
  end

  def staff_member_is_active?
    if self.staff_assigned
      validate_value = self.staff_assigned.active ? true :
          [false, "Inactive staff member cannot be assigned to manage a location"]
      return validate_value
    end
    true
  end
  
  def <=>(other)
    other.respond_to?(:effective_on) ? (other.effective_on <=> self.effective_on) : nil
  end

  # Returns the active staff that is not posted to any locations at the current instant
  def self.active_staff_not_currently_posted
    all_active_staff = StaffMember.all(:active => true)
    all_staff_posted = (StaffPosting.all.collect {|posting| posting.staff_assigned}).uniq
    all_active_staff_posted = all_staff_posted.select {|staff| staff.active}
    all_active_staff - all_active_staff_posted
  end

  #this function is for upload functionality.
  def self.from_csv(row, headers)
    staff_member = StaffMember.first(:name => row[headers[:staff_name]])
    raise ArgumentError, "Staff Member (#{row[headers[:staff_name]]}) does not exist" if staff_member.blank?

    location = BizLocation.first(:name => row[headers[:location_name]])
    raise ArgumentError, "Location (#{row[headers[:location_name]]}) does not exist" if location.blank?

    effective_on = Date.parse(row[headers[:effective_on]])
    performed_by = User.first.id
    recorded_by = User.first.id
    upload_id = row[headers[:upload_id]]
    reference = row[headers[:reference]]
    obj = assign(staff_member, location, effective_on, performed_by, recorded_by, upload_id, reference)
    if obj.saved?
      [true, obj]
    else
      [false, obj]
    end
  end

  def self.assign(staff_member, to_location, effective_on, performed_by, recorded_by, upload_id = nil, reference = nil)
    Validators::Arguments.not_nil?(staff_member, to_location, effective_on, performed_by, recorded_by)
    raise ArgumentError, "Staff member to be assigned is not an instance of StaffMember" unless staff_member.is_a?(StaffMember)
    raise ArgumentError, "Location to be assigned to is not an instance of BizLocation" unless to_location.is_a?(BizLocation)

    assignment = {}
    assignment[:staff_id]       = staff_member.id
    assignment[:at_location_id] = to_location.id
    assignment[:effective_on]   = effective_on
    assignment[:performed_by]   = performed_by
    assignment[:recorded_by]    = recorded_by
    assignment[:upload_id]      = upload_id if upload_id
    assignment[:reference]      = reference if reference
    staff_posting = create(assignment)
    raise Errors::DataError, staff_posting.errors.first.first unless staff_posting.saved?
    staff_posting
  end

  def self.get_staff_assigned(to_location_id, on_date = Date.today)
    Validators::Arguments.not_nil?(to_location_id, on_date)
    staff_assigned_to_location = []

    location_query = {}
    location_query[:at_location_id]   = to_location_id
    location_query[:effective_on.lte] = on_date
    staff_postings = all(location_query)
    return [] if staff_postings.empty?

    staff_ids  = (staff_postings.collect {|posting| posting.staff_id}).uniq
    staff_ids.each { |staff_id|
      current_assigned_location = get_assigned_location(staff_id, on_date)
      staff_assigned_to_location.push(current_assigned_location) if current_assigned_location.at_location_id == to_location_id.to_i
    }
    staff_assigned_to_location
  end

  def self.get_assigned_location(for_staff_id, on_date = Date.today)
    Validators::Arguments.not_nil?(for_staff_id, on_date)
    assigned = {}
    assigned[:staff_id] = for_staff_id
    assigned[:effective_on.lte] = on_date
    assigned[:order] = [:effective_on.desc]
    first(assigned)
  end

end