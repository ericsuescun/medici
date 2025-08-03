FactoryBot.define do
  factory :medication do
    name { Faker::Medication.name }
    description { Faker::Lorem.paragraph }
  end
end
