FactoryBot.define do
  factory :patient do
    dob { Faker::Date.birthday(min_age: 18, max_age: 80) }
    sex { %w[male female].sample }
    # state defaults to "prospect" (DB default); AASM manages transitions.
  end
end
