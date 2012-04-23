class ClientVerifications < Application
  # provides :xml, :yaml, :js

  def index
    render :verifications
  end

  # Gives the loan applications pending for verification
  def pending_verifications
    get_data(params)
    render :verifications
  end

  # Records the given CPVs and shows the list of recently recorded AND the other Loan Applications pending verifications
  def record_verifications
    get_data(params)
    
    # Show the recently recorded verifications
    facade = LoanApplicationsFacade.new(session.user)
    if params.key?('verification_status')
      params['verification_status'].keys.each do | cpv_type |
        params['verification_status'][cpv_type].keys.each do | id |
          verified_by_staff_id = params['verified_by_staff_id'][cpv_type][id]
          verification_status = params['verification_status'][cpv_type][id]
          verified_on_date = params['verified_on_date'][cpv_type][id]
          if verified_by_staff_id.empty?
            @errors[id] = "Loan Application ID #{id} : Staff ID must be provided for #{cpv_type}"
            next
          elsif verified_on_date.empty?
            @errors[id] = "Loan Application ID #{id} : Verified-on Date must be provided for #{cpv_type}"
            next
          end

          if cpv_type == Constants::Verification::CPV1
            if verification_status == Constants::Verification::VERIFIED_ACCEPTED
              facade.record_CPV1_approved(id,verified_by_staff_id, verified_on_date)
            elsif verification_status == Constants::Verification::VERIFIED_REJECTED
              facade.record_CPV1_rejected(id,verified_by_staff_id, verified_on_date)
            end
          elsif cpv_type == Constants::Verification::CPV2
            if verification_status == Constants::Verification::VERIFIED_ACCEPTED
              facade.record_CPV2_approved(id,verified_by_staff_id, verified_on_date)
            elsif verification_status == Constants::Verification::VERIFIED_REJECTED
              facade.record_CPV2_rejected(id,verified_by_staff_id, verified_on_date)
            end
          end
        end
      end
    else
      @errors['CPV Recording'] = "Choose verification status, either Approved or Rejected."
    end

    # RENDER/RE-DIRECT
    render :verifications
  end

  private

  # fetch branch, center, pending verification and completed verification
  def get_data(params)
    # GATE-KEEPING
    @errors = {}
    @branch_id = params[:branch_id]
    @center_id = params[:center_id]

    # VALIDATIONS
    unless params[:flag] == 'true'
      if @branch_id.blank?
        @errors["'verification_status'"] = "Please select a branch"
      elsif @center_id.blank?
        @errors["'verification_status'"] = "Please select center"
      end
    end
    
    # POPULATING RESPONSE AND OTHER VARIABLES
    facade = LoanApplicationsFacade.new(session.user)
    @loan_applications_pending_verification = facade.pending_CPV({:at_branch_id => params[:branch_id], :at_center_id => params[:center_id]})
    @loan_applications_recently_recorded = facade.recently_recorded_CPV(session.user.id)
  end

end # ClientVerifications
