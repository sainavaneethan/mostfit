class StandardFacade

  # All facades that are instantiated for a user extend this facade

  attr_reader :for_user, :created_at

  def initialize(for_user, with_options = {})
    @for_user = for_user; @created_at = DateTime.now
  end

  def to_s
    "#{self.class.name} instance for #{@for_user} created at #{@created_at}"
  end

  def user_id
    for_user.id
  end

  def native_performed_by_id
    for_user.staff_member.id
  end
  
end
