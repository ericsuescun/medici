require 'rails_helper'

# == Schema Information
#
# Table name: criteria_variables
#
#  id                  :bigint           not null, primary key
#  comparison_type     :string           not null
#  conditions          :text
#  criteria_order      :integer
#  description         :text
#  enabled             :boolean          default(TRUE), not null
#  name                :string           not null
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
RSpec.describe CriteriaVariable, type: :model do
  describe '#normalize_qualitative_scale' do
    it 'splits a comma-separated string into an array preserving the exact words and order' do
      profile = FactoryBot.create(:criteria_profile)
      variable = profile.criteria_variables.build(
        name: 'Severity',
        value_type: 'qualitative',
        comparison_type: 'equal',
        qualitative_scale: 'low, medium, high',
        qualitative_value: 'medium'
      )

      expect(variable.valid?).to be true
      expect(variable.qualitative_scale).to eq([ "low", "medium", "high" ]) # exact text preserved
    end

    it 'strips whitespace and ignores blank entries' do
      profile = FactoryBot.create(:criteria_profile)
      variable = profile.criteria_variables.build(
        name: 'Severity',
        value_type: 'qualitative',
        comparison_type: 'equal',
        qualitative_scale: ' low ,  , medium ,  high  ',
        qualitative_value: 'medium'
      )

      variable.valid?
      expect(variable.qualitative_scale).to eq([ "low", "medium", "high" ])
    end

    it 'normalizes arrays by trimming entries' do
      profile = FactoryBot.create(:criteria_profile)
      variable = profile.criteria_variables.build(
        name: 'Severity',
        value_type: 'qualitative',
        comparison_type: 'equal',
        qualitative_scale: [ " low ", "medium", " high" ],
        qualitative_value: 'medium'
      )

      variable.valid?
      expect(variable.qualitative_scale).to eq([ "low", "medium", "high" ])
    end
  end
end
