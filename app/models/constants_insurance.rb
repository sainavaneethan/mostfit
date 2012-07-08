module Constants
  module Insurance

    INSURANCE_TYPE_NOT_KNOWN = :insurance_type_not_known
    LIFE_INSURANCE = :life_insurance
    INSURANCE_TYPES = [INSURANCE_TYPE_NOT_KNOWN, LIFE_INSURANCE]

    INSURED_RELATIONSHIP_NOT_KNOWN = :insured_relationship_not_known
    INSURED_CLIENT = :insured_client; INSURED_SPOUSE = :insured_spouse; INSURED_GUARANTOR = :insured_guarantor
    INSURED_CLIENT_AND_SPOUSE = :insured_client_and_spouse; INSURED_CLIENT_AND_GUARANTOR = :insured_client_and_guarantor

    INSURED_PERSON_RELATIONSHIPS = [INSURED_RELATIONSHIP_NOT_KNOWN, INSURED_CLIENT, INSURED_SPOUSE, INSURED_GUARANTOR, INSURED_CLIENT_AND_SPOUSE, INSURED_CLIENT_AND_GUARANTOR]

    INSURANCE_PROPOSED = :insurance_proposed
    INSURANCE_ISSUED_STATUSES = [INSURANCE_PROPOSED]

  end
end
