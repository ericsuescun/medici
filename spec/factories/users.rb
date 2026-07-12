FactoryBot.define do
  # A User is the Devise identity; its role lives on a delegated_type :userable.
  # Build a role-specific user with a trait, e.g. FactoryBot.create(:user, :admin).
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "12345678" }
    password_confirmation { "12345678" }
    firstname { Faker::Name.first_name }
    lastname { Faker::Name.last_name }

    trait :admin do
      association :userable, factory: :admin
    end

    trait :patient do
      association :userable, factory: :patient
    end

    trait :sponsor_rep do
      association :userable, factory: :sponsor_rep
    end

    trait :trial_center_branch_rep do
      association :userable, factory: :trial_center_branch_rep
    end
  end
end
