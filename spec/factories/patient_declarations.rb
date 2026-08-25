# == Schema Information
#
# Table name: patient_declarations
#
#  id                   :bigint           not null, primary key
#  answer               :string
#  capture_mode         :string           default("public_form"), not null
#  declared_at          :datetime         not null
#  declined             :boolean          default(FALSE), not null
#  prompt               :text             not null
#  qualitative_scale    :text             default([]), not null, is an Array
#  superseded_at        :datetime
#  value_type           :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  criteria_variable_id :bigint
#  patient_id           :bigint           not null
#  recorded_by_id       :bigint
#
# Indexes
#
#  index_live_declarations_on_patient_and_variable     (patient_id,criteria_variable_id) UNIQUE WHERE (superseded_at IS NULL)
#  index_patient_declarations_on_criteria_variable_id  (criteria_variable_id)
#  index_patient_declarations_on_patient_id            (patient_id)
#  index_patient_declarations_on_recorded_by_id        (recorded_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (criteria_variable_id => criteria_variables.id) ON DELETE => nullify
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (recorded_by_id => users.id)
#
FactoryBot.define do
  factory :patient_declaration do
    patient
    association :criteria_variable
    prompt { "¿Cuál es su edad en años?" }
    answer { "30" }
    value_type { "quantitative" }
    declined { false }
    capture_mode { "public_form" }
    declared_at { Time.current }

    trait :declined do
      answer { nil }
      declined { true }
    end

    trait :by_rep do
      capture_mode { "interview" }
      association :recorded_by, factory: %i[user admin]
    end
  end
end
