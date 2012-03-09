class ClientVerification
  include DataMapper::Resource
  include Constants::Verification

  property :loan_application_id,  Integer, :nullable => false, :key => true, :index => true
  property :verification_type,    Enum.send('[]', *CLIENT_VERIFICATION_TYPES), :nullable => false, :key => true, :index => true
  property :verification_status,  Enum.send('[]', *CLIENT_VERIFICATION_STATUSES), :nullable => false, :default => NOT_VERIFIED, :key => true, :index => true
  property :verified_by_staff_id, Integer, :nullable => false
  property :verified_on_date,     Date, :nullable => false
  property :created_by_user_id,   Integer, :nullable => false
  property :created_at,           DateTime, :nullable => false, :default => DateTime.now
  
  belongs_to :loan_application
  
  validates_with_method :one_status_only_per_CPV, :record_CPV2_only_when_CPV1_approved

  # A CPV can only be approved or rejected
  def one_status_only_per_CPV
    statuses = ClientVerification.get_all_CPV_status(loan_application_id)
    status_for_type = statuses[self.verification_type]
    return [false, "Only one status can be recorded for #{self.verification_type} for #{self.loan_application_id}"] unless status_for_type == Constants::Verification::NOT_VERIFIED
    true
  end

  # CPV2 is only applicable when CPV1 is approved
  def record_CPV2_only_when_CPV1_approved
    return true unless self.verification_type == Constants::Verification::CPV2
    cpv1_is_verified = ClientVerification.is_CPV1_verified?(self.loan_application_id)
    return [false, "CPV2 can only be recorded for a client that has been approved through CPV1"] unless cpv1_is_verified
    true
  end

  # Get all CPVs on the loan application
  def self.get_CPVs(for_loan_application)
    all(:loan_application_id => for_loan_application)
  end

  # Get CPV1 on the loan application
  def self.get_CPV1(for_loan_application)
    all(:loan_application_id => for_loan_application, :verification_type => CPV1)
  end

  # Get CPV2 on the loan application
  def self.get_CPV2(for_loan_application)
    all(:loan_application_id => for_loan_application, :verification_type => CPV2)
  end

  # Submit an approved CPV1
  def self.record_CPV1_approved(loan_application_id, by_staff, on_date, by_user_id)
    record_verification(loan_application_id, CPV1, VERIFIED_ACCEPTED, by_staff, on_date, by_user_id)
  end

  # Submit a rejected CPV1
  def self.record_CPV1_rejected(loan_application_id, by_staff, on_date, by_user_id)
    record_verification(loan_application_id, CPV1, VERIFIED_REJECTED, by_staff, on_date, by_user_id)
  end

  # Submit an approved CPV2
  def self.record_CPV2_approved(loan_application_id, by_staff, on_date, by_user_id)
    record_verification(loan_application_id, CPV2, VERIFIED_ACCEPTED, by_staff, on_date, by_user_id)
  end

  # Submit a rejected CPV2
  def self.record_CPV2_rejected(loan_application_id, by_staff, on_date, by_user_id)
    record_verification(loan_application_id, CPV2, VERIFIED_REJECTED, by_staff, on_date, by_user_id)
  end

  # Get CPV1 status on the loan application
  def self.get_CPV1_status(loan_application_id)
    get_CPV_status(loan_application_id, CPV1)
  end

  # Query for whether the loan application is CPV1 accepted
  def self.is_CPV1_verified?(loan_application_id)
    get_CPV1_status(loan_application_id) == VERIFIED_ACCEPTED
  end

  # Get CPV2 status on the loan application
  def self.get_CPV2_status(loan_application_id)
    get_CPV_status(loan_application_id, CPV2)
  end

  # Get the status of all CPVs performed on a loan application as a hash with the CPV names as keys
  def self.get_all_CPV_status(loan_application_id)
    statuses = {}
    statuses[Constants::Verification::CPV1] = get_CPV1_status(loan_application_id)
    statuses[Constants::Verification::CPV2] = get_CPV2_status(loan_application_id)
    statuses
  end

  # Query for whether the loan application is CPV2 accepted
  def self.is_CPV2_verified?(loan_application_id)
    get_CPV2_status(loan_application_id) == VERIFIED_ACCEPTED
  end

  private

  # Queries CPV status for a loan application
  def self.get_CPV_status(loan_application_id, verification_type)
    cpv = first(:loan_application_id => loan_application_id, :verification_type => verification_type)
    return NOT_VERIFIED unless cpv
    cpv.verification_status
  end

  # Creates a new CPV record
  def self.record_verification(loan_application_id, verification_type, verification_status, by_staff, on_date, by_user_id)
    create(:loan_application_id => loan_application_id,
      :verification_type => verification_type,
      :verification_status => verification_status,
      :verified_by_staff_id => by_staff,
      :verified_on_date => on_date,
      :created_by_user_id => by_user_id)
  end

end