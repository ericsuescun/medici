# == Schema Information
#
# Table name: patients
#
#  id                  :bigint           not null, primary key
#  contact_address     :string
#  contact_number      :string
#  country             :string           default("")
#  dob                 :string
#  email               :string
#  firstname           :string
#  id_number           :string           default("")
#  id_type             :string           default("")
#  illness_description :text             default("")
#  lastname            :string
#  notes               :string
#  participant_code    :string
#  sex                 :string
#  state               :string           default("interested"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  study_id            :bigint
#
# Indexes
#
#  index_patients_on_participant_code  (participant_code) UNIQUE
#  index_patients_on_state             (state)
#  index_patients_on_study_id          (study_id)
#
# Foreign Keys
#
#  fk_rails_...  (study_id => studies.id)
#
FactoryBot.define do
  factory :patient do
    # Patient owns its own (encrypted) identity now — set it here rather than on
    # the User, so patient.firstname/fullname/email are populated in specs.
    firstname { Faker::Name.first_name }
    lastname { Faker::Name.last_name }
    sequence(:email) { |n| "patient#{n}@example.com" }
    dob { Faker::Date.birthday(min_age: 18, max_age: 80) }
    sex { %w[male female].sample }
    contact_number { Faker::PhoneNumber.cell_phone }
    # A patient exists to be considered for exactly one study.
    study
    # state defaults to "interested" (DB default); AASM manages transitions.

    # Lifecycle states (AASM manages transitions in the app; for test/seed
    # data writing the column directly is fine).
    trait :candidate do
      state { "candidate" }
    end

    trait :participant do
      state { "participant" }
    end

    # As the public participation form creates them: contact details only, no
    # clinical data, no account.
    trait :lead do
      firstname { nil }
      lastname { nil }
      dob { nil }
      sex { nil }
      email { nil }
    end
  end
end
