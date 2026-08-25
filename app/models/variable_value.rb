# == Schema Information
#
# Table name: variable_values
#
#  id                   :bigint           not null, primary key
#  comparison_type      :string           not null
#  conditions           :text
#  criteria_category    :string           default("primary"), not null
#  criteria_order       :integer
#  description          :text
#  enabled              :boolean          default(TRUE), not null
#  name                 :string           not null
#  qualitative_scale    :text             default([]), not null, is an Array
#  qualitative_value    :string
#  reference_value_1    :decimal(15, 6)
#  reference_value_2    :decimal(15, 6)
#  shown                :boolean          default(TRUE), not null
#  value                :string
#  value_type           :string           not null
#  variable_type        :string           default("inclusion"), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  criteria_variable_id :bigint
#  entered_by_id        :bigint
#  patient_id           :bigint           not null
#
# Indexes
#
#  index_variable_values_on_criteria_variable_id  (criteria_variable_id)
#  index_variable_values_on_entered_by_id         (entered_by_id)
#  index_variable_values_on_patient_id            (patient_id)
#  index_variable_values_on_patient_id_and_name   (patient_id,name)
#  index_vv_on_patient_type_order                 (patient_id,variable_type,criteria_order)
#
# Foreign Keys
#
#  fk_rails_...  (criteria_variable_id => criteria_variables.id) ON DELETE => nullify
#  fk_rails_...  (entered_by_id => users.id)
#  fk_rails_...  (patient_id => patients.id)
#
class VariableValue < ApplicationRecord
  include CriteriaComparable

  # Audit trail: every create/update/destroy is versioned, and whodunnit records
  # the acting user (see PaperTrail controller integration).
  has_paper_trail

  belongs_to :patient
  # The rule this answer is measuring. Optional and nullify-on-delete: the answer
  # keeps its own snapshot columns, so it stays a truthful record even if the rule
  # is later deleted. Matching answers to rules by this FK (not by `name`) is what
  # lets a rule be renamed without orphaning the patient's answer.
  belongs_to :criteria_variable, optional: true
  # The user (physician) who captured this value. Optional: existing/seeded rows
  # may have none. PaperTrail's whodunnit tracks *every* change; entered_by is the
  # convenient "who first recorded it" reference on the row itself.
  belongs_to :entered_by, class_name: "User", optional: true

  # Whether the patient's captured `value` meets this variable's comparison.
  def satisfied?
    satisfied_by?(value)
  end

  attribute :value_type, :string
  attribute :variable_type, :string
  attribute :comparison_type, :string
  attribute :criteria_category, :string

  enum :value_type, boolean: "boolean", quantitative: "quantitative", qualitative: "qualitative"
  enum :variable_type, inclusion: "inclusion", exclusion: "exclusion"
  # Snapshot of how decisive the rule was when this answer was captured — the
  # rule may be re-categorised later; what was scored at the time should not
  # change retroactively. See CriteriaVariable#criteria_category.
  enum :criteria_category, primary: "primary", secondary: "secondary"
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

  before_validation :normalize_qualitative_scale

  validates :name, presence: true
  validates :value_type, presence: true
  validates :comparison_type, presence: true

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
      if self[:qualitative_scale].length == 1
        self[:qualitative_scale] = parse_scale_string(self[:qualitative_scale].first)
      else
        self[:qualitative_scale] = self[:qualitative_scale].map { |v| v.to_s.strip }.reject(&:blank?)
      end
    end
  end

  def parse_scale_string(str)
    s = str.to_s.strip
    if s.start_with?("{") && s.end_with?("}")
      s = s[1..-2]
    end
    parts = s.split(",").map(&:strip).reject(&:blank?)
    parts.map { |p| p.gsub(/\A["']|["']\z/, "") }
  end
end
