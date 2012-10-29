class Application < Merb::Controller
  #before :desktop_user_log
  before :set_locale
  before :ensure_authenticated
  before :ensure_password_fresh
  before :ensure_can_do
  before :insert_session_to_observer
  before :add_collections, :only => [:index, :show]
  
  @@controllers  = ["clients", "payments", "staff_members", "funders", "portfolios", "funding_lines"]
  @@dependant_deletable_associations = ["history", "audit_trails", "attendances", "portfolio_loans", "postings"]

  def desktop_user_log
    if request.route.to_s.match(/\/api\/v1\/([a-z0-9_\/:]*).xml*/)
      logfile = File.open(Merb.root + '/log/api.log', 'a')  #create log file
      logfile.sync = true  #automatically flushes data to file
      api_log = Merb::Logger.new(logfile)  #constant accessible anywhere
      api_log.info("-------------- User api access log------------ ")
      api_log.info("----User: #{session.user.login}  ------  Access Time: #{DateTime.now.to_s} ----------") if session and session.user
      api_log.info("#{request.inspect}") 
    end
  end

  def set_locale
    if params[:locale]
      I18n.locale = params[:locale]
    elsif session[:locale]
      I18n.locale = session[:locale]
    elsif session.user and not session.user.preferred_locale.blank?
      I18n.locale = session.user.preferred_locale
    elsif Mfi.first and not Mfi.first.org_locale.blank?
      I18n.locale = Mfi.first.org_locale
    else
      I18n.locale = DEFAULT_LOCALE
    end
  end

  def ensure_password_fresh
    if session.key?(:change_password) and session[:change_password] and not params[:action] == "change_password"
      redirect url(:change_password)
    end
  end

  def insert_session_to_observer
    DataAccessObserver.insert_session(session.object_id)
  end

  def ensure_can_do
    login_instance = LoginInstance.get session[:login_id]
    unless login_instance.logout_time.blank?
      session.abandon!
      raise NotPrivileged, "The User's Session Terminated Successfully"
    end
    @route = Merb::Router.match(request)
    unless session.user and session.user.can_access?(@route[1], params)
      raise NotPrivileged
    end
  end

  def ensure_admin
    unless (session.user and (session.user.role == :operator || session.user.role == :administrator))
      raise NotPrivileged
    end
  end

  def determine_layout
    return params[:layout] if params[:layout] and not params[:layout].blank?
  end

  def render_to_pdf(options = nil)
    data = render_to_string(options)
    pdf = PDF::HTMLDoc.new
    pdf.set_option :bodycolor, :white
    pdf.set_option :toc, false
    pdf.set_option :portrait, true
    pdf.set_option :links, false
    pdf.set_option :webpage, true
    pdf.set_option :left, '2cm'
    pdf.set_option :right, '2cm'
    pdf << data
    pdf.generate
  end

  def delete
    raise NotPrivileged unless session.user.admin?
    raise NotFound      unless params[:model] and params[:id]
    model    = Kernel.const_get(params[:model].camel_case.singularize)
    id       = params[:id]

    raise NotFound unless model.get(id)
    obj     = model.get(id)

    error =  ""
    flag, children_present = get_dependent_relationships(obj)

    if model==Loan and not obj.disbursal_date.nil?
      flag  = false
      error += " it has already been disbursed and "
    end

    if obj.respond_to?(:verified_by) and obj.verified_by
      flag = false
      error += "verified data cannot be deleted"
    end

    # if flag is still set to true delete the object
    if flag == true and obj.destroy
      # delete all the loan history
      Attendance.all(:client_id => obj.id).destroy if model == Client
      PortfolioLoan.all(:portfolio_id => obj.id).destroy if model == Portfolio
      Posting.all(:journal_id => obj.id).destroy if model == Journal

      if model == RuleBook
        CreditAccountRule.all(:rule_book_id => obj.id).destroy!
        DebitAccountRule.all(:rule_book_id => obj.id).destroy!
      end
      if model == Account
        redirect(params[:return], :message => {:notice =>  "Deleted #{model} #{model.respond_to?(:name) ? model.name : ''} (id: #{id})"})
      elsif model == Journal
        redirect("/accounts/#journal_entries", :message => {:notice =>  "Deleted #{model} #{model.respond_to?(:name) ? model.name : ''} (id: #{id})"})
      elsif model == StaffMemberAttendance
        params[:staff_member_id] = obj.staff_member_id
        @staff_member = StaffMember.get(params[:staff_member_id])
        obj.destroy      
        redirect resource(@staff_member), :message => {:notice => "Attendance was successfully deleted"}
      else
        return_url = params[:return].split("/")[0..-3].join("/")
        redirect(return_url, :message => {:notice =>  "Deleted #{model} #{model.respond_to?(:name) ? model.name : ''} (id: #{id})"})
      end
    else
      if model == ApplicableFee
        obj.destroy
        redirect(params[:return], :message => {:notice =>  "Deleted #{model} #{model.respond_to?(:name) ? model.name : ''} (id: #{id})"})
      end

      # spitting out the error message
      error   = "Cannot delete #{model} (id: #{id}) because " + error
      error  += obj.errors.to_hash.values.flatten.join(" and ").downcase
      error  += " there are " if children_present.length > 0
      error  += children_present.collect{|k, v| 
        v==1 ? "#{v} #{k.singularize.gsub('_', ' ')}" : "#{v} #{k.gsub('_', ' ')}"
      }.join(" and ")
      error  += " under this #{model}" if children_present.length>0
      redirect(params[:return], :message => {:notice =>  "#{error}"})
    end    
  end

  def get_effective_date
    if session[:effective_date].blank?
      last_eod = EodProcess.last
      if last_eod.blank?
        date = Date.today
      else
        eods = EodPocess.all(:on_date => last_eod.on_date, :status.not => Constants::EODProcessVerificationStatus::COMPLETED)
        date = eods.blank? ? last_eod.on_date+1 : last_eod.on_date
      end
      set_effective_date(date)
      return date  #redirect url(:controller => :home, :action => :effective_date), :message => {:error => "Please select effective date"}
    else
      session[:effective_date]
    end
  end

  def set_effective_date(date)
    session.merge!(:effective_date => date)
    session[:effective_date] == date
  end

  def get_session_user_name
    session.user.staff_member.name
  end

  def get_session_user_id
    session.user.staff_member.id
  end

  private 

  def layout?
    return(request.xhr? ? false : :application)
  end
  
  def method_missing(facade_name, *args)
    raise ArgumentError, "There is no facade by the name: #{facade_name}" unless FacadeFactory::ALL_FACADES.include?(facade_name)
    for_user = session.user
    @facade_cache = {} unless @facade_cache
    facade_instance = @facade_cache[facade_name]
    unless facade_instance
      raise ArgumentError, "No user available from the current session" unless for_user
      facade_instance = FacadeFactory.instance.get_instance(facade_name, for_user)
      raise ArgumentError, "Unable to obtain an instance of #{facade_name}" unless facade_instance
      @facade_cache[facade_name] = facade_instance
    end
    facade_instance
  end


  def get_dependent_relationships(obj)
    flag  = true
    model =  obj.class
    # add child definitions to children; For loan model do not add history

    children = model.relationships.find_all{|x|
      if x[1].class==DataMapper::Associations::OneToMany::Relationship and not @@dependant_deletable_associations.include?(x[0])
        x[0]
      end
    }
   
    children_present = {}

    children.each{|x|
      relationship_method = x[0].to_sym
      unless obj.respond_to?(relationship_method)
        flag = false
        next
      end
      
      child_objects_count = obj.method(relationship_method).call.count
      if child_objects_count > 0        
        flag = false
        children_present[x[0]] = child_objects_count
      end
    }
    [flag, children_present]
  end

  def display_from_cache
    file = get_cached_filename
    return true unless File.exists?(file)
    return true if not File.mtime(file).to_date==Date.today
    throw :halt, render(File.read(file), :layout => false)
  end
  
  def store_to_cache
    file = get_cached_filename
    if not (File.exists?(file) and File.mtime(file).to_date==Date.today)
      File.open(file, "w"){|f|
        f.puts @body
      }
    end
  end
  
  def get_cached_filename
    hash = params.deep_clone
    dir = File.join(Merb.root, "public", hash.delete(:controller).to_s, hash.delete(:action).to_s)
    unless File.exists?(dir)
      FileUtils.mkdir_p(dir)
    end
    File.join(dir, (hash.empty? ? "index" : hash.collect{|k,v| "#{k}_#{v}"}))
  end

  def add_collections
    return unless session.user.role==:funder
    return unless @@controllers.include?(params[:controller])
    return if params[:controller] == "loans"
    @funder = Funder.first(:user_id => session.user.id)
    idx     = @@controllers.index(params[:controller])
    idx    += 1 if params[:action] != "index" and not (params[:controller] == "staff_members" or params[:controller] == "funding_lines")
    var     = @@controllers[idx]
    raise NotFound unless var
    instance_variable_set("@#{var}", @funder.send(var))
  end

end
