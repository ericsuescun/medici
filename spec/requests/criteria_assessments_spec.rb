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
    before { sign_in(FactoryBot.create(:user, :admin), scope: :user) }

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
  end

  context "as a patient (cannot edit patients)" do
    before { sign_in(FactoryBot.create(:user, :patient), scope: :user) }

    it "is blocked" do
      get assessment_path
      expect(response).to have_http_status(:redirect)
    end
  end
end
