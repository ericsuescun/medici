# == Schema Information
#
# Table name: patients
#
#  id                  :bigint           not null, primary key
#  adult_confirmed     :boolean          default(FALSE), not null
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
#  reported_city       :string
#  self_registered     :boolean          default(FALSE), not null
#  sex                 :string
#  state               :string           default("interested"), not null
#  submitted_by_proxy  :boolean          default(FALSE), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  study_id            :bigint
#
# Indexes
#
#  index_patients_on_participant_code  (participant_code) UNIQUE
#  index_patients_on_self_registered   (self_registered)
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

    trait :potential do
      state { "potential" }
    end

    # As the public participation form creates them: contact details only, no
    # clinical data, no account.
    # A patient as the PUBLIC form creates one. `self_registered` is what makes
    # it a lead now — the blank name used to be the marker, and stopped being
    # one when that form started asking for a name (2026-10-04). The name is
    # still blank here because it is optional on that form and plenty of people
    # leave it so; `display_name` falling back to the participant code is the
    # case worth keeping in the fixtures.
    trait :lead do
      self_registered { true }
      firstname { nil }
      lastname { nil }
      dob { nil }
      sex { nil }
      email { nil }
    end

    # A lead who did give their name — the shape the form produces most of the
    # time now, and the one a blank-name inference would have missed.
    trait :named_lead do
      self_registered { true }
      dob { nil }
      sex { nil }
    end
  end
end
