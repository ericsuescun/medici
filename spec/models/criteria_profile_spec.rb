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
#  index_criteria_profiles_on_study_id_unique       (study_id) UNIQUE WHERE (study_id IS NOT NULL)
#  index_criteria_profiles_on_user_id               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (study_id => studies.id)
#  fk_rails_...  (user_id => users.id)
#
RSpec.describe CriteriaProfile, type: :model do
  # A study's eligibility rules are singular, and since they gate promotion a
  # second profile pointing at the same study would make "which rules apply"
  # depend on physical row order — and could open the gate outright if the
  # winner happened to define no primary criteria.
  describe "one profile per study" do
    let(:study) { FactoryBot.create(:study) }

    it "rejects a second profile for the same study" do
      FactoryBot.create(:criteria_profile, study: study)
      duplicate = FactoryBot.build(:criteria_profile, study: study)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:study_id]).to be_present
    end

    it "still allows many study-less (reusable) profiles" do
      FactoryBot.create(:criteria_profile, study: nil)

      expect(FactoryBot.build(:criteria_profile, study: nil)).to be_valid
    end

    it "resolves the study's profile deterministically" do
      profile = FactoryBot.create(:criteria_profile, study: study)

      expect(study.reload.criteria_profile).to eq(profile)
    end
  end

  describe "#evaluate" do
    let(:profile) { FactoryBot.create(:criteria_profile) }
    let(:patient) { FactoryBot.create(:patient) }

    def rule(name:, variable_type:, comparison_type:, value_type: "quantitative", ref1: nil, ref2: nil, category: "primary")
      profile.criteria_variables.create!(
        name: name, variable_type: variable_type, value_type: value_type,
        comparison_type: comparison_type, reference_value_1: ref1, reference_value_2: ref2,
        criteria_category: category
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

    # The recruitment score answers a different question from the verdict: not
    # "does this patient meet the protocol" but "is there enough evidence to
    # move them forward". Only primary criteria feed it.
    describe "the recruitment score" do
      # Answer a rule, linked by FK the way the assessment controller does.
      def measure(variable, value)
        patient.variable_values.create!(
          criteria_variable: variable, name: variable.name, value: value.to_s,
          value_type: variable.value_type, comparison_type: variable.comparison_type,
          variable_type: variable.variable_type, criteria_category: variable.criteria_category,
          reference_value_1: variable.reference_value_1, reference_value_2: variable.reference_value_2
        )
      end

      it "scores the primary criteria only, so a failing secondary never holds a patient back" do
        age = rule(name: "Edad", variable_type: "inclusion", comparison_type: "between_range", ref1: 18, ref2: 40)
        weight = rule(name: "Peso", variable_type: "inclusion", comparison_type: "more_than", ref1: 50)
        height = rule(name: "Talla", variable_type: "inclusion", comparison_type: "more_than", ref1: 150, category: "secondary")
        measure(age, 30)
        measure(weight, 70)
        measure(height, 140) # fails, but it is only complementary

        result = profile.evaluate(patient.reload)
        expect(result.primary_score).to eq(100)
        expect(result.recommendation).to eq(:ready)
        expect(result).to be_promotable
        # The whole-protocol verdict still reports the secondary failure — the
        # two answers are allowed to disagree, and both are surfaced.
        expect(result).not_to be_eligible
        expect(result.secondary_concerns.map { |c| c.variable.name }).to eq([ "Talla" ])
      end

      it "holds the score down for an unmeasured primary criterion" do
        passing = 3.times.map { |i| rule(name: "P#{i}", variable_type: "inclusion", comparison_type: "more_than", ref1: 10) }
        rule(name: "Sin medir", variable_type: "inclusion", comparison_type: "more_than", ref1: 10)
        passing.each { |cv| measure(cv, 20) }

        result = profile.evaluate(patient.reload)
        expect(result.primary_score).to eq(75)
        expect(result.recommendation).to eq(:promising)
        expect(result).not_to be_promotable
        expect(result).to be_high_score
      end

      it "blocks on a failing primary criterion however high the rest scores" do
        4.times { |i| measure(rule(name: "P#{i}", variable_type: "inclusion", comparison_type: "more_than", ref1: 10), 20) }
        measure(rule(name: "Infección", variable_type: "exclusion", value_type: "boolean", comparison_type: "true"), true)

        result = profile.evaluate(patient.reload)
        expect(result.primary_score).to eq(80)
        expect(result.recommendation).to eq(:blocked)
        expect(result).not_to be_promotable
        expect(result).not_to be_high_score
      end

      it "stays pending while too little is measured" do
        measure(rule(name: "P0", variable_type: "inclusion", comparison_type: "more_than", ref1: 10), 20)
        3.times { |i| rule(name: "Sin medir #{i}", variable_type: "inclusion", comparison_type: "more_than", ref1: 10) }

        result = profile.evaluate(patient.reload)
        expect(result.primary_score).to eq(25)
        expect(result.recommendation).to eq(:pending)
      end

      it "has no score at all when the profile marks nothing primary" do
        measure(rule(name: "Talla", variable_type: "inclusion", comparison_type: "more_than", ref1: 150, category: "secondary"), 170)

        result = profile.evaluate(patient.reload)
        expect(result.primary_score).to be_nil
        expect(result.recommendation).to eq(:none)
        expect(result).not_to be_promotable
      end

      # The migration backfilled every pre-existing rule to primary precisely so
      # profiles written before the split keep scoring on all of their criteria.
      it "treats a rule with no explicit category as primary" do
        cv = profile.criteria_variables.create!(
          name: "Edad", variable_type: "inclusion", value_type: "quantitative",
          comparison_type: "between_range", reference_value_1: 18, reference_value_2: 40
        )
        expect(cv.criteria_category).to eq("primary")

        measure(cv, 30)
        expect(profile.evaluate(patient.reload).primary_score).to eq(100)
      end
    end
  end
end
