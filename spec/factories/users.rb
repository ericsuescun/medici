# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  active                 :boolean          default(FALSE), not null
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  firstname              :string
#  illness_description    :string           default("")
#  lastname               :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  userable_type          :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  role_id                :bigint
#  userable_id            :bigint
#
# Indexes
#
#  index_users_on_active                         (active)
#  index_users_on_email                          (email) UNIQUE
#  index_users_on_reset_password_token           (reset_password_token) UNIQUE
#  index_users_on_role_id                        (role_id)
#  index_users_on_userable_type_and_userable_id  (userable_type,userable_id)
#
# Foreign Keys
#
#  fk_rails_...  (role_id => roles.id)
#
FactoryBot.define do
  # A User is the Devise identity; its role lives on a delegated_type :userable.
  # Build a role-specific user with a trait, e.g. FactoryBot.create(:user, :admin).
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "12345678" }
    password_confirmation { "12345678" }
    firstname { Faker::Name.first_name }
    lastname { Faker::Name.last_name }
    # Accounts are inactive by default in the DB (an admin activates them), but
    # specs almost always want a user that can actually sign in. Use the
    # :inactive trait to exercise the gate itself.
    active { true }

    trait :inactive do
      active { false }
    end

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

    trait :platform_staff do
      association :userable, factory: :platform_staff
    end
  end
end
