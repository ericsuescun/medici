require 'rails_helper'

# The automatic half of the lifecycle, added 2026-10-04.
#
# Promotion is automatic only as far as `candidate`; the step into `potential`
# is always a person's click (Patient::AUTO_FORWARD_EVENTS). Demotion is
# automatic from either state, but only ever on a criterion that was MEASURED
# and now fails — never on one merely unrecorded, and never on the patient's
# own testimony.
RSpec.describe Patient, "#sync_state_with_criteria!" do
  let(:study) { FactoryBot.create(:study) }
  let(:profile) { FactoryBot.create(:criteria_profile, study: study) }
  let(:patient) { FactoryBot.create(:patient, study: study) }

  def rule(name:, category: "basic", comparison_type: "between_range", ref1: 18, ref2: 40)
    profile.criteria_variables.create!(
      name: name, variable_type: "inclusion", value_type: "quantitative",
      comparison_type: comparison_type, reference_value_1: ref1, reference_value_2: ref2,
      criteria_category: category
    )
  end

  def specific_rule(name:)
    rule(name: name, category: "specific", comparison_type: "more_than", ref1: 150, ref2: nil)
  end

  def measure(variable, value)
    patient.variable_values.create!(
      criteria_variable: variable, name: variable.name, value: value.to_s,
      value_type: variable.value_type, comparison_type: variable.comparison_type,
      variable_type: variable.variable_type, criteria_category: variable.criteria_category,
      reference_value_1: variable.reference_value_1, reference_value_2: variable.reference_value_2
    )
  end

  describe "promotion" do
    it "promotes interested -> candidate once the basic criteria are met" do
      measure(rule(name: "Edad"), 30)

      expect { patient.sync_state_with_criteria! }
        .to change { patient.state }.from("interested").to("candidate")
    end

    it "leaves an interested patient alone while a basic criterion is unmeasured" do
      rule(name: "Edad")

      expect { patient.sync_state_with_criteria! }.not_to change { patient.reload.state }
    end

    it "attributes the move to the system, not to whoever happened to be acting" do
      measure(rule(name: "Edad"), 30)

      PaperTrail.request(whodunnit: "42") { patient.sync_state_with_criteria! }

      expect(patient.versions.last.whodunnit).to eq(Patient::SYSTEM_WHODUNNIT)
    end

    # The whole reason `accept` is excluded from AUTO_FORWARD_EVENTS: a person
    # has to read the record before the centre approaches anybody about a trial.
    it "never promotes as far as potential, even with every criterion met" do
      measure(rule(name: "Edad"), 30)
      measure(specific_rule(name: "Talla"), 170)

      patient.sync_state_with_criteria!

      expect(patient.state).to eq("candidate")
      expect(patient.may_accept?).to be true
    end
  end

  describe "demotion" do
    it "demotes a candidate whose basic criterion now measurably fails" do
      age = measure(rule(name: "Edad"), 30)
      patient.sync_state_with_criteria!
      expect(patient.state).to eq("candidate")

      age.update!(value: "80")

      expect { patient.sync_state_with_criteria! }
        .to change { patient.state }.from("candidate").to("interested")
    end

    it "demotes a potential back to candidate when a specific criterion fails" do
      measure(rule(name: "Edad"), 30)
      talla = measure(specific_rule(name: "Talla"), 170)
      patient.sync_state_with_criteria!
      patient.accept!
      expect(patient.state).to eq("potential")

      talla.update!(value: "140")

      expect { patient.sync_state_with_criteria! }
        .to change { patient.state }.from("potential").to("candidate")
    end

    it "walks a potential all the way back when a BASIC criterion fails" do
      age = measure(rule(name: "Edad"), 30)
      measure(specific_rule(name: "Talla"), 170)
      patient.sync_state_with_criteria!
      patient.accept!

      age.update!(value: "80")
      patient.sync_state_with_criteria!

      expect(patient.state).to eq("interested")
    end

    # Adding a rule to a profile must not demote the study's existing patients:
    # nobody has measured it yet, and unmeasured is not a failure.
    it "does not demote for a criterion that is merely unmeasured" do
      measure(rule(name: "Edad"), 30)
      patient.sync_state_with_criteria!

      rule(name: "Peso", comparison_type: "more_than", ref1: 50, ref2: nil)

      expect { patient.sync_state_with_criteria! }.not_to change { patient.reload.state }
      expect(patient.state).to eq("candidate")
    end

    # Testimony can carry somebody INTO the review list and never out of it:
    # disbelieving a declaration is a rep pressing Descartar, not arithmetic.
    it "never demotes on a declaration, however badly it fails" do
      age = rule(name: "Edad")
      measure(age, 30)
      patient.sync_state_with_criteria!

      patient.patient_declarations.create!(
        criteria_variable: age, prompt: "¿Edad?", answer: "80",
        value_type: "quantitative", capture_mode: "public_form", declared_at: Time.current
      )

      expect { patient.sync_state_with_criteria! }.not_to change { patient.reload.state }
    end
  end

  # The AASM guards fail open with no rules to check, so a REP may still move
  # these patients by hand. The system may not: absence of criteria is not
  # evidence, and a study whose profile nobody has written yet must not have
  # its whole patient list filed as candidates. See Patient#auto_promotable?.
  describe "a study with nothing to check" do
    it "does not auto-promote when the study has no criteria profile" do
      orphan = FactoryBot.create(:patient, study: FactoryBot.create(:study))

      expect { orphan.sync_state_with_criteria! }.not_to change { orphan.reload.state }
      expect(orphan.may_assess?).to be true
    end

    it "does not auto-promote when the profile defines no basic criterion" do
      measure(specific_rule(name: "Talla"), 170)

      expect { patient.sync_state_with_criteria! }.not_to change { patient.reload.state }
      expect(patient.may_assess?).to be true
    end
  end

  describe "the specific score" do
    it "counts how many specific criteria are met, out of the total" do
      %w[A B C].each_with_index do |name, i|
        measure(specific_rule(name: name), i.zero? ? 100 : 200)
      end

      result = patient.reload.eligibility_result

      expect(result.specific_score).to eq(2)
      expect(result.specific_total_count).to eq(3)
      expect(result.specific_verdict).to eq(:not_met)
    end

    it "is zero, and the tier vacuously met, when the profile defines none" do
      measure(rule(name: "Edad"), 30)

      result = patient.reload.eligibility_result

      expect(result.specific_score).to eq(0)
      expect(result.specific_verdict).to eq(:none)
      expect(result.specific_criteria_met?).to be true
    end
  end
end
