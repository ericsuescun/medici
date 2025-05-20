# == Schema Information
#
# Table name: studies
#
#  id                       :bigint           not null, primary key
#  approved_at              :date
#  control_group            :string           default("")
#  ethical_approval_at      :date
#  ethical_committee        :string           default("")
#  exclusion_criteria       :string           default("")
#  first_patient_at         :date
#  global_ending_at         :date
#  inclusion_criteria       :string           default("")
#  keywords                 :string           default("")
#  local_unique_register    :string           default("")
#  main_intervention        :string           default("")
#  medical_preexistences    :string           default("")
#  medication               :string           default("")
#  participant_ending_age   :integer
#  participant_starting_age :integer
#  pathology                :string           default("")
#  public_title             :string           default("")
#  registered_at            :date
#  reviewed                 :boolean          default(FALSE)
#  sample_size              :integer
#  scientific_title         :string           default("")
#  sex                      :string           default("")
#  started_at               :date
#  study_phase              :string
#  study_status             :string
#  study_type               :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  review_user_id           :integer
#  sponsor_id               :bigint           not null
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
  standard_date = Faker::Date.on_day_of_week_between(day: [:monday, :wednesday, :friday], from: 1.year.ago, to: 1.year.from_now)

  factory :study do
    association :sponsor, factory: :sponsor

    approved_at { standard_date }
    control_group { nil }
    ethical_approval_at { standard_date }
    ethical_committee { Faker::Lorem.sentence }
    exclusion_criteria { Faker::Lorem.sentence }
    first_patient_at { standard_date }
    global_ending_at { standard_date }
    inclusion_criteria { Faker::Lorem.sentence }
    keywords { Faker::Lorem.words(number: 5, exclude_words: ['error', 'cum']) }
    local_unique_register { Faker::Number.number(digits: 10) }
    main_intervention { Faker::Lorem.sentence }
    medical_preexistences { Faker::Lorem.sentence }
    medication { Faker::Lorem.word }
    participant_ending_age { Faker::Number.normal(mean: 45, standard_deviation: 3) }
    participant_starting_age { Faker::Number.normal(mean: 40, standard_deviation: 3) }
    pathology { Faker::Lorem.words(number: 4, exclude_words: ['error', 'cum']) }
    public_title { Faker::Lorem.sentence }
    registered_at { standard_date }
    reviewed { false }
    sample_size { Faker::Number.between(from: 5, to: 20) }
    scientific_title { Faker::Science.tool }
    sex { %w[F M].sample }
    started_at { standard_date }
    study_phase { %w[I II III IV].sample }
    study_status { %w[approved rejected finished].sample }
    study_type { %w[random controlled open closed].sample }
    review_user_id { nil }
  end
end
