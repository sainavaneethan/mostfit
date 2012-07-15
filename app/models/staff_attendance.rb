class StaffAttendance
  include DataMapper::Resource
  include Constants::User
  include Constants::Properties

  property :id,              Serial
  property :staff_member_id, *INTEGER_NOT_NULL
  property :attendance,      Enum.send('[]', *ATTENDANCE_STATUSES), :nullable => false, :default => DEFAULT_ATTENDANCE_STATUS
  property :on_date,         *DATE_NOT_NULL
  property :at_location,     *INTEGER_NOT_NULL
  property :performed_by,    *INTEGER_NOT_NULL
  property :recorded_by,     *INTEGER_NOT_NULL
  property :created_at,      *CREATED_AT
  property :updated_at,      *UPDATED_AT
  
  def self.record_attendance(for_staff_id, was_present, on_date, at_location_id, performed_by_id, recorded_by_id)
    attendance_values = to_attendance(for_staff_id, was_present, on_date, at_location_id, performed_by_id, recorded_by_id)
    roster = create(attendance_values)
    raise Errors::DataError, roster.errors.first.first unless roster.saved?
    roster
  end

  def self.update_attendance(for_staff_id, was_present, on_date, at_location_id, performed_by_id, recorded_by_id)
    Validators::Arguments.not_nil?(for_staff_id, was_present, on_date, at_location_id, performed_by_id, recorded_by_id)
    Validators::Arguments.is_id?(for_staff_id, at_location_id, performed_by_id, recorded_by_id)
    attendance_values = {}
    attendance_values[:staff_member_id] = for_staff_id
    attendance_values[:on_date]         = on_date
    attendance_values[:at_location]     = at_location_id

    roster = first(attendance_values)
    raise Errors::DataMissingError, "No attendance record was found for staff with ID: #{for_staff_id} at the location with ID: #{at_location_id} on the date: #{on_date}" unless roster

    attendance_val = was_present ? Constants::User::PRESENT_ATTENDANCE_STATUS :
        Constants::User::ABSENT_ATTENDANCE_STATUS
    roster.attendance   = attendance_val
    roster.performed_by = performed_by_id
    roster.recorded_by  = recorded_by_id
    raise Errors::DataError, roster.errors.first.first unless roster.save
    roster
  end

  def self.get_all_recorded_attendance_status_at_location(at_location_id, on_date)
    all(:at_location => at_location_id, :on_date => on_date)
  end

  def self.to_attendance(for_staff_id, was_present, on_date, at_location_id, performed_by_id, recorded_by_id)
    Validators::Arguments.not_nil?(for_staff_id, was_present, on_date, at_location_id, performed_by_id, recorded_by_id)
    Validators::Arguments.is_id?(for_staff_id, at_location_id, performed_by_id, recorded_by_id)
    attendance_values = {}
    attendance_values[:staff_member_id] = for_staff_id
    attendance_val = was_present ? Constants::User::PRESENT_ATTENDANCE_STATUS :
        Constants::User::ABSENT_ATTENDANCE_STATUS
    attendance_values[:attendance]      = attendance_val
    attendance_values[:on_date]         = on_date
    attendance_values[:at_location]     = at_location_id
    attendance_values[:performed_by]    = performed_by_id
    attendance_values[:recorded_by]     = recorded_by_id
    attendance_values
  end

end
