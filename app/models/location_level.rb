class LocationLevel
  include DataMapper::Resource
  
  property :id,         Serial
  property :level,      Integer, :nullable => false, :unique => true, :min => 0
  property :name,       String, :nullable => false
  property :created_at, DateTime, :nullable => false, :default => DateTime.now

  has n, :biz_locations

  def self.location_level_for_new
    LocationLevel.all.blank? ? 0 : LocationLevel.last.level + 1
  end

end
