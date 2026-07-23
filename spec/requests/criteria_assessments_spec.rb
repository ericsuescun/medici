require 'rails_helper'

RSpec.describe "Criteria assessments", type: :request do
  let(:profile) { FactoryBot.create(:criteria_profile) }
  let(:patient) { FactoryBot.create(:patient) }
  let!(:age) do
    profile.criteria_variables.create!(
      name: "Edad", variable_type: "inclusion", value_type: "quantitative",
      comparison_type: "between_range", reference_value_1: 18, reference_value_2: 40
    )
  end

  def assessment_path
    patient_criteria_assessment_path(patient, criteria_profile_id: profile.id)
  end

  context "as an admin (can edit patients)" do
    let(:admin_user) { FactoryBot.create(:user, :admin) }
    before { sign_in(admin_user, scope: :user) }

    it "renders the assessment form" do
      get assessment_path
      expect(response).to be_successful
      expect(response.body).to include("Evaluación de criterios")
      expect(response.body).to include("Edad")
    end

    it "saves submitted values and re-evaluates" do
      patch assessment_path, params: { values: { age.id.to_s => "30" } }

      expect(response).to redirect_to(assessment_path)
      expect(patient.variable_values.find_by(name: "Edad").value).to eq("30")
      expect(profile.evaluate(patient.reload)).to be_eligible
    end

    it "attributes the captured value to the acting user and versions the change" do
      patch assessment_path, params: { values: { age.id.to_s => "30" } }

      value = patient.variable_values.find_by(name: "Edad")
      expect(value.entered_by).to eq(admin_user)
      # PaperTrail records the change with the acting user as whodunnit.
      expect(value.versions.last.whodunnit).to eq(admin_user.id.to_s)
    end

    it "links the captured value to the rule by FK" do
      patch assessment_path, params: { values: { age.id.to_s => "30" } }

      expect(patient.variable_values.find_by(name: "Edad").criteria_variable).to eq(age)
    end

    it "shows the brief's out-of-reach and pending sections" do
      profile.criteria_variables.create!(
        name: "Peso", variable_type: "inclusion", value_type: "quantitative",
        comparison_type: "more_than", reference_value_1: 50
      )
      patient.variable_values.create!(criteria_variable: age, name: "Edad", value: "50", value_type: "quantitative", comparison_type: "between_range")

      get assessment_path
      expect(response.body).to include("fuera de alcance") # Edad = 50 fails the 18–40 range
      expect(response.body).to include("por medir")        # Peso not yet measured
    end

    it "offers a promote action that transitions the patient's state" do
      # A interested is promoted to candidate via the AASM `assess` event.
      expect {
        post transition_patient_path(patient, event: "assess")
      }.to change { patient.reload.state }.from("interested").to("candidate")
    end
  end

  context "as a patient (cannot edit patients)" do
    before { sign_in(FactoryBot.create(:user, :patient), scope: :user) }

    it "is blocked" do
      get assessment_path
      expect(response).to have_http_status(:redirect)
    end
  end
end
