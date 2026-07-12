FactoryBot.define do
  factory :medication do
    sequence(:name) { |n| "Medication #{n}" }
    description { Faker::Lorem.paragraph }
  end
end
