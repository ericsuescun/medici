require 'rails_helper'

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
#  index_criteria_profiles_on_user_id               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (study_id => studies.id)
#  fk_rails_...  (user_id => users.id)
#
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

    # Regression: answers used to be matched to rules by `name`, so renaming a
    # rule silently orphaned every answer. They are matched by FK now.
    it "keeps the answer linked when the rule is renamed (FK, not name)" do
      cv = rule(name: "Edad", variable_type: "inclusion", comparison_type: "between_range", ref1: 18, ref2: 40)
      patient.variable_values.create!(
        criteria_variable: cv, name: cv.name, value: "30",
        value_type: "quantitative", comparison_type: "between_range"
      )
      expect(profile.evaluate(patient.reload)).to be_eligible

      cv.update!(name: "Edad (años)")

      result = profile.evaluate(patient.reload)
      expect(result).to be_eligible, "rename orphaned the answer"
      expect(result).to be_complete
    end

    describe "the brief" do
      it "reports passing / failing / pending and a verdict symbol" do
        pass = rule(name: "Edad", variable_type: "inclusion", comparison_type: "between_range", ref1: 18, ref2: 40)
        fail_rule = rule(name: "Peso", variable_type: "inclusion", comparison_type: "more_than", ref1: 50)
        rule(name: "Talla", variable_type: "inclusion", comparison_type: "more_than", ref1: 150)
        patient.variable_values.create!(criteria_variable: pass, name: pass.name, value: "30", value_type: "quantitative", comparison_type: "between_range")
        patient.variable_values.create!(criteria_variable: fail_rule, name: fail_rule.name, value: "40", value_type: "quantitative", comparison_type: "more_than")

        result = profile.evaluate(patient.reload)
        expect(result.passing.map { |c| c.variable.name }).to eq([ "Edad" ])
        expect(result.failing.map { |c| c.variable.name }).to eq([ "Peso" ])
        expect(result.pending.map { |c| c.variable.name }).to eq([ "Talla" ])
        expect(result.answered_count).to eq(2)
        expect(result.total_count).to eq(3)
        expect(result.verdict).to eq(:not_eligible)
      end
    end
  end
end
