class AuditTrails < Application
  PER_PAGE = 20

  def index
    raise NotFound if not params[:audit_for] 
    model = params[:audit_for][:controller] == 'new_clients' ? 'Client' :params[:audit_for][:controller].singularize.camelcase

    if params[:audit_for].key?(:id)
      id = params[:audit_for][:id]
    elsif params[:audit_for][:controller] == "lendings" and params[:audit_for].key?(:client_id)
      id = params[:audit_for][:client_id]
      model = "Client"
    elsif params[:audit_for][:controller] == "payment_transactions" and params[:audit_for].key?(:loan_id) and not params[:audit_for].key?(:id)
      id = params[:audit_for][:loan_id]
      model = "Lending"
    end

    model = "BizLocation" if (params[:audit_for][:controller] == "user_locations")
    model = "SimpleFeeProduct" if (params[:audit_for][:controller] == "simple_fee_products")
    model = "SimpleInsurancePolicy" if (params[:audit_for][:controller] == "simple_insurance_policies")
    model = "LocationLevel" if (params[:audit_for][:controller] == "location_levels")
    model = "ThirdParty" if (params[:audit_for][:controller] == "third_parties")
    model = "LoanPurpose" if (params[:audit_for][:controller] == "loan_purposes")
    model = "Occupation" if (params[:audit_for][:controller] == "occupations")
    model = "ClientGroup" if (params[:audit_for][:controller] == "client_groups")
    model = "PrioritySectorList" if (params[:audit_for][:controller] == "priority_sector_lists")
    model = "PslSubCategory" if (params[:audit_for][:controller] == "psl_sub_categories")
    model = "DocumentType" if (params[:audit_for][:controller] == "document_types")
    model = "StockRegister" if (params[:audit_for][:controller] == "stock_registers")
    model = "AssetCategory" if (params[:audit_for][:controller] == "asset_categories")
    model = "AssetSubCategory" if (params[:audit_for][:controller] == "asset_sub_categories")
    model = "AssetType" if (params[:audit_for][:controller] == "asset_types")
    model = "Reason" if (params[:audit_for][:controller] == "reasons")
    model = "AssetRegister" if (params[:audit_for][:controller] == "asset_registers")
    model = "LocationHoliday" if (params[:audit_for][:controller] == "location_holidays")
    model = "ChequeBook" if (params[:audit_for][:controller] == "cheque_books")
    model = "Lending" if not ["BizLocation", "Lending", "Client", "PaymentTransaction"].include?(model) and /Lending^/.match(model)   

    if (params[:audit_for][:controller] == "center_cycles")
      model = "CenterCycle"
      id = params[:audit_for][:center_cycle_id]
    end

    if (params[:audit_for][:controller] == "admin")
      model = "Mfi"
      @obj = Kernel.const_get(model).first
      id = @obj.id
    else
      @obj = Kernel.const_get(model).get(id)
    end

    if model == "Lending"
      model = ["Lending", @obj.class.to_s]
    end

    @trails = AuditTrail.all(:auditable_id => id, :auditable_type => model, :order => [:created_at.desc])
    partial "audit_trails/list", :layout => false
  end

  def show(id)
    from_date = params[:from_date] ? Date.parse(params[:from_date]) : Date.today
    to_date = params[:to_date] ? Date.parse(params[:to_date]) : Date.today

    hash = {:created_at.gte => from_date, :created_at.lt => to_date + 1}
    hash[:action] = params[:change_action] if params[:change_action] and not params[:change_action].blank?
    hash[:user_id] = User.get(params[:user]).id if params[:user] and not params[:user].blank?

    if params[:auditable_type] and not params[:auditable_type].blank?
      hash[:auditable_type] = params[:auditable_type]
      model = Kernel.const_get(params[:auditable_type])
      @properties = Searches.new({}).send(:get_properties_for, model).map{|x| x.to_sym}

      if params[:col] and not params[:col].blank? and @properties and @properties.include?(params[:col].to_sym) and model
        @col = if model.properties.map{|x| x.name}.include?(params[:col].to_sym)
                 params[:col].to_sym
               elsif model.relationships.keys.include?(params[:col]) and model.relationships[params[:col]].child_key
                 model.relationships[params[:col]].child_key.first.name
               else
                 nil
               end
      end
    end

    @trails = AuditTrail.all(hash)
    page = (params[:page]||1).to_i
    @offset = (page-1)*PER_PAGE

    if @col
      @trails = @trails.reject{|trail|
        not trail.changes.reduce({}){|s,x| s+=x}.keys.include?(@col)
      }
      @length = @trails.length
      @trails = @trails[@offset..(page-1)*PER_PAGE + PER_PAGE - 1]
    else
      @length = AuditTrail.all(hash).count
      @trails = @trails.all(:offset => @offset, :limit => PER_PAGE)
    end
  
    render
  end
end
