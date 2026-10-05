require 'rails_helper'

# == Schema Information
#
# Table name: patients
#
#  id                  :bigint           not null, primary key
#  adult_confirmed     :boolean          default(FALSE), not null
#  contact_address     :string
#  contact_number      :string
#  country             :string           default("")
#  dob                 :string
#  email               :string
#  firstname           :string
#  id_number           :string           default("")
#  id_type             :string           default("")
#  illness_description :text             default("")
#  lastname            :string
#  notes               :string
#  participant_code    :string
#  reported_city       :string
#  self_registered     :boolean          default(FALSE), not null
#  sex                 :string
#  state               :string           default("interested"), not null
#  submitted_by_proxy  :boolean          default(FALSE), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  study_id            :bigint
#
# Indexes
#
#  index_patients_on_participant_code  (participant_code) UNIQUE
#  index_patients_on_self_registered   (self_registered)
#  index_patients_on_state             (state)
#  index_patients_on_study_id          (study_id)
#
# Foreign Keys
#
#  fk_rails_...  (study_id => studies.id)
#
RSpec.describe Patient, type: :model do
  subject(:patient) { FactoryBot.create(:patient) }

  describe "AASM lifecycle" do
    it "starts in the interested state" do
      expect(patient).to be_interested
      expect(patient.state).to eq("interested")
    end

    it "assess: interested -> candidate" do
      expect { patient.assess! }.to change(patient, :state).from("interested").to("candidate")
    end

    it "accept: candidate -> participant" do
      patient.assess!
      expect { patient.accept! }.to change(patient, :state).from("candidate").to("potential")
    end

    it "discard: candidate -> interested" do
      patient.assess!
      expect { patient.discard! }.to change(patient, :state).from("candidate").to("interested")
    end

    it "reject: participant -> candidate" do
      patient.assess!
      patient.accept!
      expect { patient.reject! }.to change(patient, :state).from("potential").to("candidate")
    end

    it "forbids an illegal transition (accept from interested)" do
      expect(patient.may_accept?).to be false
      expect { patient.accept! }.to raise_error(AASM::InvalidTransition)
    end
  end

  # A patient only moves deeper into a trial once the criteria of the tier that
  # step asks for have recorded values AND comply. Enforced as AASM guards so no
  # code path can skip them — and because PatientPolicy delegates to
  # `may_assess?`, the same rules reach the policy and every view.
  describe "the criteria gate on forward transitions" do
    let(:study) { FactoryBot.create(:study) }
    let(:profile) { FactoryBot.create(:criteria_profile, study: study) }
    let(:patient) { FactoryBot.create(:patient, study: study) }

    def rule(name:, category: "basic", variable_type: "inclusion", comparison_type: "between_range", ref1: 18, ref2: 40)
      profile.criteria_variables.create!(
        name: name, variable_type: variable_type, value_type: "quantitative",
        comparison_type: comparison_type, reference_value_1: ref1, reference_value_2: ref2,
        criteria_category: category
      )
    end

    def measure(variable, value)
      patient.variable_values.create!(
        criteria_variable: variable, name: variable.name, value: value.to_s,
        value_type: variable.value_type, comparison_type: variable.comparison_type,
        variable_type: variable.variable_type, criteria_category: variable.criteria_category,
        reference_value_1: variable.reference_value_1, reference_value_2: variable.reference_value_2
      )
    end

    it "blocks the transition while a basic criterion is unrecorded" do
      rule(name: "Edad")

      expect(patient.reload.may_assess?).to be false
      expect { patient.assess! }.to raise_error(AASM::InvalidTransition)
      expect(patient.reload.state).to eq("interested")
    end

    it "blocks the transition when a basic criterion is recorded but fails" do
      measure(rule(name: "Edad"), 50)

      expect(patient.reload.may_assess?).to be false
    end

    it "allows the transition once every basic criterion is recorded and met" do
      measure(rule(name: "Edad"), 30)

      expect(patient.reload.may_assess?).to be true
      expect { patient.assess! }.to change(patient, :state).from("interested").to("candidate")
    end

    # The tiers gate DIFFERENT steps. This used to read "ignores secondary
    # criteria entirely"; since 2026-10-04 a specific criterion is ignored by
    # `assess` and decisive for `accept`, so the pin is that the two disagree.
    it "lets a failing specific criterion through assess and stops it at accept" do
      measure(rule(name: "Edad"), 30)
      measure(rule(name: "Talla", category: "specific", comparison_type: "more_than", ref1: 150, ref2: nil), 140)

      result = patient.reload.eligibility_result
      expect(result.specific_failing.map { |c| c.variable.name }).to eq([ "Talla" ])

      expect(patient.may_assess?).to be true
      patient.assess!
      expect(patient.may_accept?).to be false
    end

    it "opens accept only when the specific criteria are recorded and met too" do
      measure(rule(name: "Edad"), 30)
      talla = rule(name: "Talla", category: "specific", comparison_type: "more_than", ref1: 150, ref2: nil)
      patient.reload.assess!

      # Unrecorded is not compliance on this tier either.
      expect(patient.may_accept?).to be false

      measure(talla, 170)
      expect(patient.reload.may_accept?).to be true
    end

    it "opens accept with nothing to check when the profile defines no specific criteria" do
      measure(rule(name: "Edad"), 30)
      patient.reload.assess!

      expect(patient.may_accept?).to be true
    end

    it "does not block a patient whose study has no criteria profile" do
      expect(patient.eligibility_result).to be_nil
      expect(patient.may_assess?).to be true
    end

    it "does not block when the profile marks nothing basic" do
      rule(name: "Talla", category: "specific")

      expect(patient.reload.may_assess?).to be true
    end

    it "gates accept on the basic tier as well as assess" do
      age = measure(rule(name: "Edad"), 30)
      patient.reload.assess!
      expect(patient.may_accept?).to be true

      # A rule added after the fact leaves the patient short again.
      rule(name: "Peso", comparison_type: "more_than", ref1: 50, ref2: nil)
      expect(patient.reload.may_accept?).to be false
      expect(age).to be_persisted
    end

    it "never gates the backward steps, so a patient can always be walked back" do
      age = measure(rule(name: "Edad"), 30)
      patient.reload.assess!

      # Break the criteria out from under the candidate.
      age.update!(value: "50")

      expect(patient.reload.may_assess?).to be false
      expect { patient.discard! }.to change(patient, :state).from("candidate").to("interested")
    end
  end

  # Two tiers of evidence for two tiers of transition: the patient's own
  # DECLARATIONS can open interested → candidate (triage — "worth a rep's
  # look"), but candidate → participant only ever opens on investigator-
  # recorded values. A patient can self-report onto the review list, never
  # into the trial.
  describe "the self-report triage tier" do
    let(:study) { FactoryBot.create(:study) }
    let(:profile) { FactoryBot.create(:criteria_profile, study: study) }
    let(:patient) { FactoryBot.create(:patient, study: study) }
    let!(:age) do
      profile.criteria_variables.create!(
        name: "Edad", variable_type: "inclusion", value_type: "quantitative",
        comparison_type: "between_range", reference_value_1: 18, reference_value_2: 40,
        patient_prompt: "¿Cuál es su edad?"
      )
    end

    def declare(variable, answer, declined: false)
      patient.patient_declarations.create!(
        criteria_variable: variable, prompt: variable.patient_prompt || variable.name,
        answer: declined ? nil : answer.to_s, declined: declined,
        value_type: variable.value_type, qualitative_scale: variable.qualitative_scale,
        capture_mode: "public_form", declared_at: Time.current
      )
    end

    it "opens assess when the declarations satisfy every basic criterion" do
      declare(age, 30)

      expect(patient.reload.basic_criteria_met_by_self_report?).to be true
      expect(patient.may_assess?).to be true
      expect { patient.assess! }.to change(patient, :state).from("interested").to("candidate")
    end

    it "keeps assess closed when a declaration fails the rule" do
      declare(age, 50)

      expect(patient.reload.may_assess?).to be false
    end

    it "treats a declined declaration ('No sé') as unanswered, not as failing" do
      declare(age, nil, declined: true)

      result = patient.reload.self_report_result
      expect(result.basic_pending.map { |c| c.variable.name }).to eq([ "Edad" ])
      expect(patient.may_assess?).to be false
    end

    it "scores the declaration with the LIVE rule, so a rule change re-judges old testimony" do
      declare(age, 30)
      expect(patient.reload.basic_criteria_met_by_self_report?).to be true

      age.update!(reference_value_1: 35, reference_value_2: 60)

      expect(patient.reload.basic_criteria_met_by_self_report?).to be false
    end

    it "ignores superseded declarations — only the live testimony speaks" do
      first = declare(age, 50)
      first.supersede!
      declare(age, 30)

      expect(patient.reload.basic_criteria_met_by_self_report?).to be true
    end

    it "never opens accept: joining the trial requires investigator-recorded values" do
      declare(age, 30)
      patient.reload.assess!

      expect(patient.may_accept?).to be false

      patient.variable_values.create!(
        criteria_variable: age, name: age.name, value: "30",
        value_type: "quantitative", comparison_type: "between_range",
        criteria_category: "basic", reference_value_1: 18, reference_value_2: 40
      )
      expect(patient.reload.may_accept?).to be true
    end

    it "does not fail open: no declarations means no self-reported evidence" do
      expect(patient.reload.basic_criteria_met_by_self_report?).to be false
      # ...but the clinical tier's fail-open for no-profile patients is separate:
      # this patient HAS a profile with an unmeasured primary, so both close.
      expect(patient.may_assess?).to be false
    end
  end
end
