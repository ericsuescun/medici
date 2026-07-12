require 'rails_helper'

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
