FactoryBot.define do
  factory :soap_note do
    association :patient
    encounter_date { Date.current }
    # At least one section must be present (model validation).
    subjective { "Patient reports intermittent headaches for two weeks." }
    assessment { "Tension-type headache, provisional." }
  end
end
