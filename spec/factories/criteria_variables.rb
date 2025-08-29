FactoryBot.define do
  factory :criteria_variable do
    association :criteria_profile

    name { "Variable #{Faker::Lorem.word}" }
    description { Faker::Lorem.sentence }

    value_type { "qualitative" }
    comparison_type { "equal" }

    qualitative_scale { ["low", "medium", "high"] }
    qualitative_value { "medium" }

    enabled { true }
    shown { true }
  end
end
