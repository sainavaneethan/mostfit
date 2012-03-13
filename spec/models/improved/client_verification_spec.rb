require File.join( File.dirname(__FILE__), '..', '..', "spec_helper" )

describe ClientVerification do

  before(:all) do
    @time_datum = Time.now
    @on_date = Date.today
    @by_p_staff_id = 3;
    @by_x_user_id = 29;
    @counter = 1
  end

  it "should record a CPV1 approved when requested" do
    loan_application_id = ((Time.now - @time_datum) * 1000).to_i
    ClientVerification.record_CPV1_approved(loan_application_id, @by_p_staff_id, @on_date, @by_x_user_id)
    ClientVerification.is_CPV1_verified?(loan_application_id).should == true
  end

  it "should record a CPV1 rejected when requested" do
    loan_application_id = ((Time.now - @time_datum) * 1000).to_i
    ClientVerification.record_CPV1_rejected(loan_application_id, @by_p_staff_id, @on_date, @by_x_user_id)
    ClientVerification.is_CPV1_verified?(loan_application_id).should == false
  end
  
  it "should not allow different statuses to be recorded for a CPV1 for a loan application" do
    loan_application_id = ((Time.now - @time_datum) * 1000).to_i

    ClientVerification.record_CPV1_rejected(loan_application_id, @by_p_staff_id, @on_date, @by_x_user_id)
    ClientVerification.is_CPV1_verified?(loan_application_id).should == false

    ClientVerification.record_CPV1_approved(loan_application_id, @by_p_staff_id, @on_date, @by_x_user_id)
    ClientVerification.is_CPV1_verified?(loan_application_id).should == false
  end

  it "should disallow recording CPV2 on a loan application that has no CPV1" do
    loan_application_id = ((Time.now - @time_datum) * 1000).to_i

    ClientVerification.get_CPV1_status(loan_application_id).should == Constants::Verification::NOT_VERIFIED
    ClientVerification.get_CPV2_status(loan_application_id).should == Constants::Verification::NOT_VERIFIED

    ClientVerification.record_CPV2_approved(loan_application_id, @by_p_staff_id, @on_date, @by_x_user_id)
    ClientVerification.get_CPV2_status(loan_application_id).should == Constants::Verification::NOT_VERIFIED

    ClientVerification.record_CPV2_rejected(loan_application_id, @by_p_staff_id, @on_date, @by_x_user_id)
    ClientVerification.get_CPV2_status(loan_application_id).should == Constants::Verification::NOT_VERIFIED
  end

  it "should tell that CPV process is incomplete when no CPVs are recorded" do
    #when no CPV is recorded
    loan_application_id = ((Time.now - @time_datum) * 1000).to_i
    ClientVerification.get_CPVs(loan_application_id).should == []
    ClientVerification.is_cpv_complete?(loan_application_id).should == false
  end

  it "should tell that CPV process is incomplete when only CPV1 is recorded" do
    #when only CPV1 is recorded as approved
    loan_application_id = ((Time.now - @time_datum) * 1000).to_i
    ClientVerification.record_CPV1_approved(loan_application_id, @by_p_staff_id, @on_date, @by_x_user_id)
    ClientVerification.is_cpv_complete?(loan_application_id).should == false

  end
  
  it "should tell that CPV is process is complete when CPV1 is rejected" do
     loan_application_id = ((Time.now - @time_datum) * 1000).to_i
     ClientVerification.record_CPV1_rejected(loan_application_id, @by_p_staff_id, @on_date, @by_x_user_id)
     ClientVerification.is_cpv_complete?(loan_application_id).should == true
  end

 
  it "should tell that CPV process is complete when CPV2 has been recorded" do
    #when both CPV1 and CPV2 are recorded 
    loan_application_id = ((Time.now - @time_datum) * 1000).to_i
    ClientVerification.record_CPV1_approved(loan_application_id, @by_p_staff_id, @on_date, @by_x_user_id)
    ClientVerification.record_CPV2_rejected(loan_application_id, @by_p_staff_id, @on_date, @by_x_user_id)
    ClientVerification.is_cpv_complete?(loan_application_id).should == true

    loan_application_id = ((Time.now - @time_datum) * 1000).to_i
    ClientVerification.record_CPV1_approved(loan_application_id, @by_p_staff_id, @on_date, @by_x_user_id)
    ClientVerification.record_CPV2_approved(loan_application_id, @by_p_staff_id, @on_date, @by_x_user_id)
    ClientVerification.is_cpv_complete?(loan_application_id).should == true
  end

end
