# == Schema Information
#
# Table name: studies
#
#  id                              :bigint           not null, primary key
#  committee_approved              :boolean          default(FALSE), not null
#  completed_at                    :date
#  exclusion_criteria              :string
#  first_patient_at                :date
#  global_ending_at                :date
#  inclusion_criteria              :string
#  local_health_authority_approved :boolean          default(FALSE), not null
#  main_intervention               :string
#  public_title                    :string
#  reviewed                        :boolean
#  sample_size                     :integer
#  scientific_title                :string
#  sex                             :string
#  short_title                     :string           default("")
#  started_at                      :date
#  study_phase                     :string
#  study_status                    :string
#  study_type                      :string
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  review_user_id                  :integer
#  sponsor_id                      :bigint           not null
#
# Indexes
#
#  index_studies_on_sponsor_id  (sponsor_id)
#
# Foreign Keys
#
#  fk_rails_...  (sponsor_id => sponsors.id)
#
FactoryBot.define do
  factory :study do
    association :sponsor, factory: :sponsor

    public_title { Faker::Lorem.sentence }
    scientific_title { Faker::Lorem.sentence }
    short_title { Faker::Lorem.words(number: 3).join(' ') }
    inclusion_criteria { Faker::Lorem.paragraph }
    exclusion_criteria { Faker::Lorem.paragraph }
    main_intervention { Faker::Lorem.sentence }

    # Categories are seeded reference data, not auto-attached: specs that need
    # them opt in via the trait so counts stay deterministic.
    trait :with_categories do
      after(:create) { |study| study.categories << FactoryBot.create(:category) }
    end
    sample_size { Faker::Number.between(from: 50, to: 1000) }
    sex { [ 'male', 'female', 'both' ].sample }

    # Every study now carries a type; interventional is the historical shape
    # (a phase I-IV trial), so it is the factory default.
    study_type { "interventional" }
    study_status { Study.study_statuses.keys.sample }
    study_phase { Study.study_phases.keys.sample }

    started_at { Faker::Date.backward(days: 300) }
    completed_at { Faker::Date.backward(days: 250) }
    first_patient_at { Faker::Date.backward(days: 150) }
    global_ending_at { Faker::Date.forward(days: 365) }

    reviewed { false }
    review_user_id { nil }
  end
end
