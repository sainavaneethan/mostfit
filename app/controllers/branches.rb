class Branches < Application
  provides :xml, :yaml, :js
  include DateParser

  def index
    if session.user.role == :staff_member
      @branches = Branch.for_staff_member(session.user.staff_member).paginate(:page => params[:page], :per_page => 15)
    else
      @branches = (@branches || Branch.all).paginate(:page => params[:page], :per_page => 15)
    end
    display @branches
  end

  def show(id)
    @option = params[:option] if params[:option]
    @branch = Branch.get(id)
    raise NotFound unless @branch
    @centers = @branch.centers_with_paginate({:meeting_day => params[:meeting_day]}, session.user)
    if params[:format] and API_SUPPORT_FORMAT.include?(params[:format])
      display [@branch, @centers]
    else
      display [@branch, @centers], 'centers/index', :layout => layout?
    end
  end
  
  def today(id)
    @date = params[:date] == nil ? Date.today : params[:date]
    @branch = Branch.get(id)
    raise NotFound unless @branch
    @centers = @branch.centers
    display [@branch, @centers]
  end

  def new
    only_provides :html
    @branch = Branch.new
    display @branch
  end

  def create(branch)
    @branch = Branch.new(branch)
    if @branch.save
      redirect(params[:return]||resource(:branches), :message => {:notice => "Branch '#{@branch.name}' (Id:#{@branch.id}) successfully created"})
    else
      message[:error] = "Branch failed to be created"
      render :new  # error messages will show
    end
  end

  def edit(id)
    only_provides :html
    @branch = Branch.get(id)
    raise NotFound unless @branch
    display @branch
  end

  def update(id, branch)
    @branch = Branch.get(id)
    raise NotFound unless @branch
    if @branch.update_attributes(branch)
      redirect(params[:return]||resource(:branches), :message => {:notice => "Branch '#{@branch.name}' (Id:#{@branch.id}) has been edited successfully"})
    else
      display @branch, :edit  # error messages will show
    end
  end

  def delete(id)
    edit(id)  # so far identical to edit
  end

  def destroy(id)
    @branch = Branch.get(id)
    raise NotFound unless @branch
    if @branch.destroy
      redirect resource(:branches), :message => {:notice => "Branch '#{@branch.name}' (Id:#{@branch.id}) has been deleted successfully"}
    else
      raise InternalServerError
    end
  end

  def centers
    if params[:id] 
      branch = Branch.get(params[:id])
      next unless branch
      return("<option value=''>Select center</option>"+branch.centers(:order => [:name]).map{|cen| "<option value=#{cen.id}>#{cen.name}</option>"}.join)
    end
  end

  def accounts
    if params[:id]
      branch = Branch.get(params[:id])
      next unless branch
      return("<option value=''>Select account</option>"+branch.accounts(:order => [:name]).map{|acc| "<option value=#{acc.id}>#{acc.name}</option>"}.join)
    end
  end

  def cash_accounts
    if params[:id]
      branch = Branch.get(params[:id])
      next unless branch
      return("<option value=''>Select account</option>"+branch.accounts(:account_category => "Cash", :order => [:name]).map{|a| "<option value=#{a.id}>#{a.name}</option>"}.join)
    end
  end

  def bank_accounts
    if params[:id]
      branch = Branch.get(params[:id])
      next unless branch
      return("<option value=''>Select account</option>"+branch.accounts(:account_category => "Bank", :order => [:name]).map{|a| "<option value=#{a.id}>#{a.name}</option>"}.join)
    end
  end

  # this redirects to the proper url, used from the router
  def redirect_to_show(id)
    raise NotFound unless @branch = Branch.get(id)
    redirect resource(@branch)
  end
end # Branches
