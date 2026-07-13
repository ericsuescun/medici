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
#  index_criteria_profiles_on_user_id               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (study_id => studies.id)
#  fk_rails_...  (user_id => users.id)
#
class CriteriaProfile < ApplicationRecord
  belongs_to :study, optional: true
  belongs_to :user

  has_many :criteria_variables, dependent: :destroy

  validates :name, presence: true

  # Evaluate `patient` against this profile's enabled variables. Patient answers
  # (VariableValues) are matched to variables by `name` — the app's denormalized
  # snapshot design has no FK linking the two. Returns an EligibilityResult.
  def evaluate(patient)
    answers = patient.variable_values.index_by(&:name)

    checks = criteria_variables
             .select(&:enabled)
             .sort_by { |cv| cv.criteria_order || 0 }
             .map do |cv|
      answer = answers[cv.name]
      met = answer ? cv.satisfied_by?(answer.value) : nil
      EligibilityResult::Check.new(variable: cv, value: answer&.value, met: met)
    end

    EligibilityResult.new(checks)
  end
end
