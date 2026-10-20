require "rails_helper"
require Rails.root.join("db/seeds/example_criteria_profiles")

# fill_missing_prompts! runs against production's demo data, where REAL studies
# also carry example profiles — so "only the studies it was told" is the
# property that keeps a question from reaching a real study's applicants.
RSpec.describe ExampleCriteriaProfiles, ".fill_missing_prompts!" do
  let(:owner) { FactoryBot.create(:user, :admin) }

  # A profile as an older seed built it: the example rules, no specific prompts.
  def legacy_profile_for(study)
    ExampleCriteriaProfiles.build_profile!(study, ExampleCriteriaProfiles::AREA_NAMES.first, owner).tap do |profile|
      profile.criteria_variables.where(criteria_category: "specific").update_all(patient_prompt: nil)
    end
  end

  def specific_prompted(profile)
    profile.criteria_variables.where(criteria_category: "specific").where.not(patient_prompt: [ nil, "" ]).count
  end

  it "fills the specific prompts an older seed left blank" do
    profile = legacy_profile_for(FactoryBot.create(:study))

    expect(ExampleCriteriaProfiles.fill_missing_prompts!).to eq(6)
    expect(specific_prompted(profile)).to eq(6)
  end

  it "touches only the studies it is given" do
    demo = legacy_profile_for(FactoryBot.create(:study))
    real = legacy_profile_for(FactoryBot.create(:study))

    ExampleCriteriaProfiles.fill_missing_prompts!(studies: [ demo.study_id ])

    expect(specific_prompted(demo)).to eq(6)
    expect(specific_prompted(real)).to eq(0)
  end

  it "never rewrites a prompt somebody edited" do
    profile = legacy_profile_for(FactoryBot.create(:study))
    visits = profile.criteria_variables.find_by!(name: "Disponibilidad para visitas presenciales")
    visits.update!(patient_prompt: "¿Puede venir los martes?")

    ExampleCriteriaProfiles.fill_missing_prompts!

    expect(visits.reload.patient_prompt).to eq("¿Puede venir los martes?")
  end

  it "is idempotent" do
    legacy_profile_for(FactoryBot.create(:study))
    ExampleCriteriaProfiles.fill_missing_prompts!

    expect(ExampleCriteriaProfiles.fill_missing_prompts!).to eq(0)
  end
end

# Seeded patients' STATE must follow from their evidence (2026-10-19). Seeds
# used to create patients already at Candidato/Potencial and then hand them
# values with no regard for that state; in the dev graph 87 of 134 candidates
# and 108 of 110 potentials sat at a step their own record had not earned.
RSpec.describe ExampleCriteriaProfiles, "states that follow the evidence" do
  let(:owner) { FactoryBot.create(:user, :admin) }
  let(:study) { FactoryBot.create(:study) }
  let!(:profile) { ExampleCriteriaProfiles.build_profile!(study, ExampleCriteriaProfiles::AREA_NAMES.first, owner) }

  def supported?(patient)
    patient.candidate? ? patient.criteria_met_for_candidate? : patient.criteria_met_for_potential?
  end

  describe ".establish!" do
    let(:patient) { FactoryBot.create(:patient, study: study) }

    it "files a candidate through the automatic step, on values that support it" do
      ExampleCriteriaProfiles.establish!(patient, "candidate")

      expect(patient.reload.state).to eq("candidate")
      expect(patient.criteria_met_for_candidate?).to be(true)
      expect(patient.versions.last.whodunnit).to eq(Patient::SYSTEM_WHODUNNIT)
    end

    it "takes a potential the rest of the way with Aceptar, signed by the seed" do
      ExampleCriteriaProfiles.establish!(patient, "potential")

      expect(patient.reload.state).to eq("potential")
      expect(patient.criteria_met_for_potential?).to be(true)
      expect(patient.versions.last.whodunnit).to eq(ExampleCriteriaProfiles::SEED_WHODUNNIT)
    end
  end

  it "spreads freshly seeded patients across the lifecycle with every state supported" do
    patients = FactoryBot.create_list(:patient, 8, study: study)

    ExampleCriteriaProfiles.populate_answers!(profile)

    states = patients.map { |p| p.reload.state }
    expect(states).to include("candidate", "potential", "interested")
    patients.reject(&:interested?).each { |p| expect(supported?(p)).to be(true), "##{p.id} at #{p.state}" }
  end

  describe ".reconcile_states!" do
    it "gives a patient written straight into a state the evidence for it, and leaves supported ones alone" do
      stranded = FactoryBot.create(:patient, :potential, study: study) # the old seeds' shape: no evidence
      earned = FactoryBot.create(:patient, study: study).tap { |p| ExampleCriteriaProfiles.establish!(p, "candidate") }
      earned_values = earned.variable_values.reload.map { |v| [ v.criteria_variable_id, v.value ] }.sort

      expect(ExampleCriteriaProfiles.reconcile_states!(Patient.where(id: [ stranded.id, earned.id ]))).to eq(1)

      expect(stranded.reload.state).to eq("potential")
      expect(supported?(stranded)).to be(true)
      expect(earned.variable_values.reload.map { |v| [ v.criteria_variable_id, v.value ] }.sort).to eq(earned_values)
    end
  end
end
