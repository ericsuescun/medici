# == Schema Information
#
# Table name: criteria_variables
#
#  id                  :bigint           not null, primary key
#  comparison_type     :string           not null
#  conditions          :text
#  criteria_category   :string           default("basic"), not null
#  criteria_order      :integer
#  description         :text
#  enabled             :boolean          default(TRUE), not null
#  name                :string           not null
#  patient_prompt      :text
#  qualitative_scale   :text             default([]), not null, is an Array
#  qualitative_value   :string
#  reference_value_1   :decimal(15, 6)
#  reference_value_2   :decimal(15, 6)
#  shown               :boolean          default(TRUE), not null
#  value_type          :string           not null
#  variable_type       :string           default("inclusion"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  criteria_profile_id :bigint           not null
#
# Indexes
#
#  index_criteria_variables_on_criteria_profile_id           (criteria_profile_id)
#  index_criteria_variables_on_criteria_profile_id_and_name  (criteria_profile_id,name)
#  index_cv_on_profile_type_order                            (criteria_profile_id,variable_type,criteria_order)
#
# Foreign Keys
#
#  fk_rails_...  (criteria_profile_id => criteria_profiles.id)
#
class CriteriaVariable < ApplicationRecord
  include CriteriaComparable

  # Audit trail: eligibility rules feed a patient's verdict, so changes are versioned.
  has_paper_trail

  belongs_to :criteria_profile

  # Patient answers captured against this rule. nullify (not destroy): deleting a
  # rule leaves each answer's snapshot intact as a historical record.
  has_many :variable_values, dependent: :nullify

  attribute :value_type, :string
  attribute :variable_type, :string
  attribute :comparison_type, :string
  attribute :criteria_category, :string

  enum :value_type, boolean: "boolean", quantitative: "quantitative", qualitative: "qualitative"

  enum :variable_type, inclusion: "inclusion", exclusion: "exclusion"

  # How much this rule weighs on the recruitment decision — a third axis,
  # orthogonal to value_type (the datatype) and variable_type (the polarity):
  #
  #   basic    — decisive, and phrased so a patient can answer it themselves.
  #              These carry EligibilityResult#basic_score and gate
  #              interested → candidate; they are also the only rules the
  #              public questionnaire is allowed to ask.
  #   specific — investigator-measured. These carry #specific_score (a COUNT of
  #              how many are met, which is what orders a rep's queue) and,
  #              together with the basic tier, gate candidate → potential.
  enum :criteria_category, basic: "basic", specific: "specific"

  enum :comparison_type,
       less_than: "less_than",
       less_than_or_equal: "less_than_or_equal",
       more_than: "more_than",
       more_than_or_equal: "more_than_or_equal",
       between_range: "between_range",
       out_of_range: "out_of_range",
       equal: "equal",
       different: "different",
       true: "true",
       false: "false"

  # Rules the public questionnaire may ask a patient. ONE condition: the rule
  # carries a patient_prompt.
  #
  # The prompt's PRESENCE is the switch, and writing one is the editorial act —
  # it is the CEI-approved participant wording, which is what
  # `patient_self_report_enabled` attests. The questionnaire renders the prompt
  # and nothing else (never name/rule_summary/thresholds — those describe the
  # protocol), so a rule without a prompt cannot be asked at all.
  #
  # This was BASIC-only between 2026-08-24 and 2026-10-04, on the reasoning that
  # "a specific criterion cannot move the outcome, so asking about it only
  # lengthens the form". That reasoning expired when the specific tier became a
  # gate of its own: specific answers now decide the step to `potential` and
  # carry the count that orders a rep's queue, so they move an outcome plainly.
  #
  # What has NOT changed, and must not: a declaration is testimony, never a
  # measurement. Answers land in patient_declarations, which has no comparison
  # columns and cannot be scored on its own, and `criteria_met_for_potential?`
  # reads investigator VariableValues only. So a patient may now be ASKED a
  # specific criterion, and still cannot self-report their way past candidate.
  #
  # Most specific criteria have no business being asked (a patient does not know
  # their IGA score or BSA%). The ones worth a prompt are the ones they can
  # actually speak to — prior treatments that failed, willingness to attend
  # visits, other trials, habits. Leaving the rest promptless is how the form
  # stays short enough to finish.
  scope :askable_to_patient, -> { where(enabled: true).where.not(patient_prompt: [ nil, "" ]) }

  def askable_to_patient?
    enabled? && patient_prompt.present?
  end

  # Normalize qualitative_scale when provided as a comma-separated string from forms
  before_validation :normalize_qualitative_scale

  validates :name, presence: true
  validates :value_type, presence: true
  validates :comparison_type, presence: true
  validates :criteria_category, presence: true

  validate :qualitative_value_in_scale, if: -> { value_type == "qualitative" }

  private

  def normalize_qualitative_scale
    return if self[:qualitative_scale].nil?

    raw = nil
    begin
      raw = self.attribute_before_type_cast("qualitative_scale")
    rescue NoMethodError
      raw = nil
    end

    if raw.is_a?(String)
      self[:qualitative_scale] = parse_scale_string(raw)
    elsif self[:qualitative_scale].is_a?(String)
      self[:qualitative_scale] = parse_scale_string(self[:qualitative_scale])
    elsif self[:qualitative_scale].is_a?(Array)
      # Handle the case where AR typecasts a string into a single-element array
      if self[:qualitative_scale].length == 1
        self[:qualitative_scale] = parse_scale_string(self[:qualitative_scale].first)
      else
        self[:qualitative_scale] = self[:qualitative_scale].map { |v| v.to_s.strip }.reject(&:blank?)
      end
    end
  end

  def qualitative_value_in_scale
    true
  end

  def parse_scale_string(str)
    s = str.to_s.strip
    # Remove PG array curly braces if present
    if s.start_with?("{") && s.end_with?("}")
      s = s[1..-2]
    end
    parts = s.split(",").map(&:strip).reject(&:blank?)
    # Remove wrapping single/double quotes from parts
    parts.map { |p| p.gsub(/\A["']|["']\z/, "") }
  end
end
