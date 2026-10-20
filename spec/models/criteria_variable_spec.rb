require 'rails_helper'

# == Schema Information
#
# Table name: criteria_variables
#
#  id                  :bigint           not null, primary key
#  asked_online        :boolean          default(TRUE), not null
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

  # A specific question can be kept off the public questionnaire so the centre
  # asks it instead; a basic one never can — auto-triage needs a declaration
  # for every basic criterion.
  describe "asking online" do
    let(:profile) { FactoryBot.create(:criteria_profile) }

    def rule(category, prompt: "¿Pregunta?", asked_online: true)
      FactoryBot.create(:criteria_variable, criteria_profile: profile, criteria_category: category,
                        patient_prompt: prompt, asked_online: asked_online)
    end

    it "asks a specific question online only while its switch is on" do
      online = rule("specific")
      offline = rule("specific", asked_online: false)

      expect(online).to be_askable_to_patient
      expect(offline).not_to be_askable_to_patient
      expect(offline).to be_asked_by_centre
      expect(CriteriaVariable.askable_to_patient.ids).to contain_exactly(online.id)
    end

    it "keeps a basic question online, whatever the switch was set to" do
      basic = rule("basic", asked_online: false)

      expect(basic.asked_online).to be(true)
      expect(basic).to be_askable_to_patient
      expect(basic).not_to be_asked_by_centre
    end

    it "asks a basic question online even when the column was written past the model" do
      basic = rule("basic")
      basic.update_column(:asked_online, false)

      expect(CriteriaVariable.askable_to_patient).to include(basic)
      expect(basic.reload).to be_askable_to_patient
    end

    it "puts a centre-asked question back online when it becomes basic" do
      variable = rule("specific", asked_online: false)
      variable.update!(criteria_category: "basic")

      expect(variable.asked_online).to be(true)
      expect(CriteriaVariable.askable_to_patient).to include(variable)
    end

    it "is asked by nobody without a prompt, or when disabled" do
      unprompted = rule("specific", prompt: nil, asked_online: false)
      disabled = rule("specific", asked_online: false).tap { |v| v.update!(enabled: false) }

      expect(unprompted).not_to be_asked_by_centre
      expect(disabled).not_to be_asked_by_centre
      expect(CriteriaVariable.askable_to_patient).to be_empty
    end
  end
end
