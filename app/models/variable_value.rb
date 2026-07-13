# == Schema Information
#
# Table name: variable_values
#
#  id                :bigint           not null, primary key
#  comparison_type   :string           not null
#  conditions        :text
#  criteria_order    :integer
#  description       :text
#  enabled           :boolean          default(TRUE), not null
#  name              :string           not null
#  qualitative_scale :text             default([]), not null, is an Array
#  qualitative_value :string
#  reference_value_1 :decimal(15, 6)
#  reference_value_2 :decimal(15, 6)
#  shown             :boolean          default(TRUE), not null
#  value             :string
#  value_type        :string           not null
#  variable_type     :string           default("inclusion"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  patient_id        :bigint           not null
#
# Indexes
#
#  index_variable_values_on_patient_id           (patient_id)
#  index_variable_values_on_patient_id_and_name  (patient_id,name)
#  index_vv_on_patient_type_order                (patient_id,variable_type,criteria_order)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id)
#
class VariableValue < ApplicationRecord
  belongs_to :patient

  attribute :value_type, :string
  attribute :variable_type, :string
  attribute :comparison_type, :string

  enum :value_type, boolean: "boolean", quantitative: "quantitative", qualitative: "qualitative"
  enum :variable_type, inclusion: "inclusion", exclusion: "exclusion"
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
