class Home < Application

  def index
    set_effective_date(Date.today) if session[:effective_date].blank?
    @location_levels = choice_facade.visible_locations(session.user.staff_member.id, get_effective_date)
    display @location_levels
  end

  def effective_date
    @date = get_effective_date
    display @date
  end

  def update_effective_date
    message = {}
    date = Date.parse(params[:effective_date])
    if set_effective_date(date)
      message[:notice] = "Effective date update successfully"
    else
      message[:error] = "Effective date cannot updated"
    end
    redirect url(:controller => :home, :action => 'index'), :message => message
  end

end