require 'rails_helper'

RSpec.describe CriteriaProfile, type: :model do
  describe "#evaluate" do
    let(:profile) { FactoryBot.create(:criteria_profile) }
    let(:patient) { FactoryBot.create(:patient) }

    def rule(name:, variable_type:, comparison_type:, value_type: "quantitative", ref1: nil, ref2: nil)
      profile.criteria_variables.create!(
        name: name, variable_type: variable_type, value_type: value_type,
        comparison_type: comparison_type, reference_value_1: ref1, reference_value_2: ref2
      )
    end

    # Give the patient a value for a rule (matched by name). value_type/
    # comparison_type only satisfy VariableValue validations; evaluate uses the
    # rule's comparison.
    def answer(name:, value:, value_type: "quantitative", comparison_type: "equal")
      patient.variable_values.create!(name: name, value: value.to_s, value_type: value_type, comparison_type: comparison_type)
    end

    it "is eligible when all inclusions pass and no exclusion triggers" do
      rule(name: "Edad", variable_type: "inclusion", comparison_type: "between_range", ref1: 18, ref2: 40)
      rule(name: "Infección", variable_type: "exclusion", value_type: "boolean", comparison_type: "true")
      answer(name: "Edad", value: 30)
      answer(name: "Infección", value: false, value_type: "boolean", comparison_type: "true")

      result = profile.evaluate(patient)
      expect(result).to be_eligible
      expect(result).to be_complete
    end

    it "is ineligible when an inclusion fails" do
      rule(name: "Edad", variable_type: "inclusion", comparison_type: "between_range", ref1: 18, ref2: 40)
      answer(name: "Edad", value: 50)

      expect(profile.evaluate(patient)).not_to be_eligible
    end

    it "is ineligible when an exclusion is triggered" do
      rule(name: "Infección", variable_type: "exclusion", value_type: "boolean", comparison_type: "true")
      answer(name: "Infección", value: true, value_type: "boolean", comparison_type: "true")

      result = profile.evaluate(patient)
      expect(result).not_to be_eligible
      expect(result.failing.map { |c| c.variable.name }).to include("Infección")
    end

    it "is incomplete and not eligible when a value is missing" do
      rule(name: "Edad", variable_type: "inclusion", comparison_type: "between_range", ref1: 18, ref2: 40)

      result = profile.evaluate(patient)
      expect(result).not_to be_complete
      expect(result).not_to be_eligible
      expect(result.missing.map { |c| c.variable.name }).to include("Edad")
    end
  end
end
