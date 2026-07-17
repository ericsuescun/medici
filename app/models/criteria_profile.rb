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
  # Audit trail for the eligibility rule set (changes ripple to patient verdicts).
  has_paper_trail

  belongs_to :study, optional: true
  belongs_to :user

  has_many :criteria_variables, dependent: :destroy

  validates :name, presence: true

  # Evaluate `patient` against this profile's enabled variables. Answers
  # (VariableValues) are matched to rules by FK (criteria_variable_id), so a rule
  # can be renamed without orphaning the patient's answer. `name` is only a
  # fallback for legacy rows written before the FK existed. Returns an
  # EligibilityResult.
  def evaluate(patient)
    values = patient.variable_values.to_a
    by_id = values.index_by(&:criteria_variable_id)
    by_name = values.reject(&:criteria_variable_id).index_by(&:name)

    checks = criteria_variables
             .select(&:enabled)
             .sort_by { |cv| cv.criteria_order || 0 }
             .map do |cv|
      answer = by_id[cv.id] || by_name[cv.name]
      met = answer ? cv.satisfied_by?(answer.value) : nil
      EligibilityResult::Check.new(variable: cv, value: answer&.value, met: met)
    end

    EligibilityResult.new(checks)
  end
end
