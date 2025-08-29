FactoryBot.define do
  factory :criteria_profile do
    name { "Profile #{Faker::Lorem.word}" }
    description { Faker::Lorem.sentence }
    association :user
    association :study
  end
end
