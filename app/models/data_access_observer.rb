class DataAccessObserver
  include DataMapper::Observer
  observe *(DataMapper::Model.descendants.to_a - [AuditTrail, LoanDueStatus, ClientAdministration, LoanAuthorization, ClientVerification, LoanFile, LoanApplication, FundingLineAddition, Securitization, Encumberance, BaseScheduleLineItem, LoanBorrower, LoanStatusChange, LoanBaseSchedule, LoanAdministration, LoginInstance, Voucher, Ledger, CostCenter, AccountingRule, OverlapReportResponse, Upload, JournalType, LocationLink, TimedAmount, LoanScheduleTemplate, FeeAdministration, AccountsChart, LendingProductLocation, MeetingCalendar, ScheduleTemplateLineItem, MeetingSchedule, LocationManagement] + [BizLocation, ClientGroup, Client, Lending, PaymentTransaction, StaffMember, SimpleFeeProduct, SimpleInsurancePolicy, CenterCycle, Mfi, LocationLevel, Funder, FundingLine, Tranch, ThirdParty, LoanPurpose, Occupation, ClientGroup, PrioritySectorList, PslSubCategory, DocumentType, StockRegister, AssetCategory, AssetSubCategory, AssetType, Reason, AssetRegister, LocationHoliday, ChequeBook, NewFunder, NewFundingLine, NewTranch]).uniq # strange bug where observer drops some of the descnedants.
  
  def self.insert_session(id)
    @_session = ObjectSpace._id2ref(id)
    @_user = @_session.user
  end


  def self.get_object_state(obj, type)
    #load lazy attributes forcefully here
    @ributes = original_attributes = obj.original_attributes.map{|k,v| {k.name => (k.lazy? ? obj.send(k.name) : v)}}.inject({}){|s,x| s+=x}
    @action = type
  end
  
  def self.log(obj)
    f = File.open("log/#{obj.class}.log","a")
    begin
      if obj
        attributes = obj.attributes
        if @ributes
          diff = @ributes.diff(attributes).reject{|x| x.to_s.match(/^c_/)} # reject the caching properties, defined by c_xxxx
          diff = diff.map{|k| 
            {k => [@ributes[k],attributes[k]]} if k != :updated_at and not (@ributes[k].nil? and attributes[k].class==String and attributes[k].blank?)
          }
          diff=diff.compact
        else
          diff = [attributes.select{|k, v| v and not v.blank? and not v==0}.to_hash]
        end
        if diff.length>0 and diff.find{|x| x.keys.include?(:discriminator)}
          index = diff.index(diff.find{|x| x.keys.include?(:discriminator)})
          diff[index][:discriminator] = diff[index][:discriminator].map{|x| x.to_s if x}
        end
        return if diff.length==0
        model = (/Lending$/.match(obj.class.to_s) ? "Lending" : obj.class.to_s)
        unless @_user.nil?
          user_role = @_user.staff_member.designation.role_class
          log = AuditTrail.new(:auditable_id => obj.id, :action => @action, :changes => diff.to_yaml, :type => :log, :user_role => user_role,
                               :auditable_type => model, :user => @_user, :created_at => DateTime.now)
          log.save
        end
      end
    rescue Exception => e
      p diff if diff
      Merb.logger.info(e.to_s)
      Merb.logger.info(e.backtrace.join("\n"))
    end
  end

  def self.check_session(obj)
  end


  before :create do
    DataAccessObserver.check_session(self)
    DataAccessObserver.get_object_state(self, :create)
  end  
  
  before :valid? do
    DataAccessObserver.check_session(self)
  end

  before :save do
    # DataAccessObserver.check_session(self)
    DataAccessObserver.get_object_state(self, :update) if not self.new?
  end  
  
  after :save do
    DataAccessObserver.log(self)
  end  
  
  before :destroy do
    DataAccessObserver.check_session(self)
    DataAccessObserver.get_object_state(self, :destroy) if not self.new?
  end

  after :destroy do
    DataAccessObserver.log(self)
  end
  
  before :destroy! do
  end

end
