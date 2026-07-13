# == Schema Information
#
# Table name: criteria_variables
#
#  id                  :bigint           not null, primary key
#  comparison_type     :string           not null
#  conditions          :text
#  criteria_order      :integer
#  description         :text
#  enabled             :boolean          default(TRUE), not null
#  name                :string           not null
#  qualitative_scale   :text             default([]), not null, is an Array
#  qualitative_value   :string
#  reference_value_1   :decimal(15, 6)
#  reference_value_2   :decimal(15, 6)
#  shown               :boolean          default(TRUE), not null
#  value_type          :string           not null
#  variable_type       :string           default("inclusion"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  criteria_profile_id :bigint           not null
#
# Indexes
#
#  index_criteria_variables_on_criteria_profile_id           (criteria_profile_id)
#  index_criteria_variables_on_criteria_profile_id_and_name  (criteria_profile_id,name)
#  index_cv_on_profile_type_order                            (criteria_profile_id,variable_type,criteria_order)
#
# Foreign Keys
#
#  fk_rails_...  (criteria_profile_id => criteria_profiles.id)
#
FactoryBot.define do
  factory :criteria_variable do
    association :criteria_profile

    name { "Variable #{Faker::Lorem.word}" }
    description { Faker::Lorem.sentence }

    value_type { "qualitative" }
    comparison_type { "equal" }

    qualitative_scale { [ "low", "medium", "high" ] }
    qualitative_value { "medium" }

    enabled { true }
    shown { true }
  end
end
