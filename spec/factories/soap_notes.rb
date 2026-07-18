# == Schema Information
#
# Table name: soap_notes
#
#  id             :bigint           not null, primary key
#  encounter_date :date             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  author_id      :bigint
#  patient_id     :bigint           not null
#
# Indexes
#
#  index_soap_notes_on_author_id   (author_id)
#  index_soap_notes_on_patient_id  (patient_id)
#
# Foreign Keys
#
#  fk_rails_...  (author_id => users.id) ON DELETE => nullify
#  fk_rails_...  (patient_id => patients.id)
#
FactoryBot.define do
  factory :soap_note do
    association :patient
    encounter_date { Date.current }
    # At least one section must be present (model validation).
    subjective { "Patient reports intermittent headaches for two weeks." }
    assessment { "Tension-type headache, provisional." }
  end
end
