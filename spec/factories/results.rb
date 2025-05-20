# == Schema Information
#
# Table name: results
#
#  id          :bigint           not null, primary key
#  description :string           default("")
#  result_type :string           default("empty")
#  title       :string           default("")
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  study_id    :bigint           not null
#
# Indexes
#
#  index_results_on_study_id  (study_id)
#
# Foreign Keys
#
#  fk_rails_...  (study_id => studies.id)
#
FactoryBot.define do
  factory :result do
    association :study, factory: :study

    description { Faker::Lorem.paragraph }
    result_type { %w[Primary Secondary].sample }
    title { Faker::Lorem.sentence }
  end
end
