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

  enum :variable_type, boolean: 'boolean', numeric: 'numeric'

  enum :comparison_type,
       less_than: 'less_than',
       less_than_or_equal: 'less_than_or_equal',
       more_than: 'more_than',
       more_than_or_equal: 'more_than_or_equal',
       between_range: 'between_range',
       out_of_range: 'out_of_range',
       equal: 'equal',
       different: 'different',
       true: 'true',
       false: 'false'

  validates :name, presence: true
  validates :variable_type, presence: true
  validates :comparison_type, presence: true
end