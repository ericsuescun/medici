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
class CriteriaProfile < ApplicationRecord
  # Audit trail for the eligibility rule set (changes ripple to patient verdicts).
  has_paper_trail

  belongs_to :study, optional: true
  belongs_to :user

  has_many :criteria_variables, dependent: :destroy

  validates :name, presence: true
  # One profile per study (a study's eligibility rules are singular). Enforced in
  # the DB by a partial unique index; this is here so the form shows an error
  # instead of a constraint violation. `allow_nil` because study is optional —
  # a profile with no study is a reusable template, and there may be many.
  validates :study_id, uniqueness: true, allow_nil: true

  # Evaluate `patient` against this profile's enabled variables. Answers
  # (VariableValues) are matched to rules by FK (criteria_variable_id), so a rule
  # can be renamed without orphaning the patient's answer. `name` is only a
  # fallback for legacy rows written before the FK existed. Returns an
  # EligibilityResult.
  #
  # Every enabled variable is evaluated regardless of category; splitting the
  # decisive (primary) ones out of the complementary (secondary) ones is the
  # EligibilityResult's job, since the same evaluation answers both the
  # protocol question and the recruitment-score one.
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

  # Evaluate the patient's DECLARATIONS (self-reported testimony) against this
  # profile's enabled variables — the triage-tier counterpart of #evaluate.
  #
  # Note who does the scoring: the LIVE rule. A PatientDeclaration deliberately
  # carries no comparison columns (see that model), so the only way to judge it
  # is `cv.satisfied_by?(declaration.answer)` — polarity, thresholds and
  # category all come from the current rule, and the declaration stays
  # unscorable on its own. A declined declaration ("No sé") answers nothing, so
  # it evaluates like a missing value rather than a failing one.
  #
  # Feeds Patient#primary_criteria_met_by_self_report?, which gates ONLY the
  # interested → candidate triage step. The clinical tier (candidate →
  # participant) never reads declarations.
  def evaluate_self_reports(patient)
    declarations = patient.patient_declarations.live.index_by(&:criteria_variable_id)

    checks = criteria_variables
             .select(&:enabled)
             .sort_by { |cv| cv.criteria_order || 0 }
             .map do |cv|
      declaration = declarations[cv.id]
      raw = declaration&.declined? ? nil : declaration&.answer
      met = raw.nil? ? nil : cv.satisfied_by?(raw)
      EligibilityResult::Check.new(variable: cv, value: raw, met: met)
    end

    EligibilityResult.new(checks)
  end
end
