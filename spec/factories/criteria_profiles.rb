# == Schema Information
#
# Table name: criteria_profiles
#
#  id          :bigint           not null, primary key
#  description :text
#  name        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  study_id    :bigint
#  user_id     :bigint           not null
#
# Indexes
#
#  index_criteria_profiles_on_study_id              (study_id)
#  index_criteria_profiles_on_study_id_and_user_id  (study_id,user_id)
#  index_criteria_profiles_on_study_id_unique       (study_id) UNIQUE WHERE (study_id IS NOT NULL)
#  index_criteria_profiles_on_user_id               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (study_id => studies.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :criteria_profile do
    # Sequenced, not Faker::Lorem.word: that vocabulary is small enough that two
    # profiles in one example collide every so often, and the specs that assert
    # one sponsor's profile is ABSENT from another's page then pass or fail on
    # a coin toss — a collision could equally hide a real scoping leak.
    sequence(:name) { |n| "Profile #{n} #{Faker::Lorem.word}" }
    description { Faker::Lorem.sentence }
    association :user, factory: %i[user admin]
    association :study
  end
end
