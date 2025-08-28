# == Schema Information
#
# Table name: criteria_variables
#
#  id                  :bigint           not null, primary key
#  name                :string           not null
#  description         :text
#  variable_type       :string           not null
#  reference_value_1   :decimal(15, 6)
#  reference_value_2   :decimal(15, 6)
#  comparison_type     :string           not null
#  conditions          :text
#  criteria_profile_id :bigint           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_criteria_variables_on_criteria_profile_id           (criteria_profile_id)
#  index_criteria_variables_on_criteria_profile_id_and_name  (criteria_profile_id,name)
#
# Foreign Keys
#
#  fk_rails_...  (criteria_profile_id => criteria_profiles.id)
#
class CriteriaVariable < ApplicationRecord
  belongs_to :criteria_profile

  enum :variable_type, boolean: "boolean", numeric: "numeric", qualitative: "qualitative"

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

  # Normalize qualitative_scale when provided as a comma-separated string from forms
  # before_validation :normalize_qualitative_scale

  validates :name, presence: true
  validates :variable_type, presence: true
  validates :comparison_type, presence: true

  validate :qualitative_value_in_scale, if: -> { variable_type == "qualitative" }

  private

  # def normalize_qualitative_scale
  #   return if self[:qualitative_scale].nil?
  #
  #   if self[:qualitative_scale].is_a?(String)
  #     self[:qualitative_scale] = self[:qualitative_scale]
  #                                 .split(",")
  #                                 .map(&:strip)
  #                                 .reject(&:blank?)
  #   elsif self[:qualitative_scale].is_a?(Array)
  #     self[:qualitative_scale] = self[:qualitative_scale].map { |v| v.to_s.strip }.reject(&:blank?)
  #   end
  # end

  def qualitative_value_in_scale
    true
  end
end
