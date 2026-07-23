require 'rails_helper'

RSpec.describe "Patient briefings", type: :request do
  let(:study) { FactoryBot.create(:study) }
  let(:patient) { FactoryBot.create(:patient, study: study) }
  let(:profile) { FactoryBot.create(:criteria_profile, study: study) }

  describe "as an admin" do
    let(:admin_user) { FactoryBot.create(:user, :admin) }
    before { sign_in(admin_user, scope: :user) }

    it "renders the briefing with the eligibility verdict and sections" do
      cv = profile.criteria_variables.create!(
        name: "Edad", variable_type: "inclusion", value_type: "quantitative",
        comparison_type: "between_range", reference_value_1: 18, reference_value_2: 40
      )
      patient.variable_values.create!(criteria_variable: cv, name: "Edad", value: "50", value_type: "quantitative", comparison_type: "between_range")
      FactoryBot.create(:soap_note, patient: patient)

      get patient_briefing_path(patient)

      expect(response).to be_successful
      expect(response.body).to include("Edad")                       # out-of-reach criterion listed
      expect(response.body).to include(I18n.t("criteria_assessments.not_eligible"))
      expect(response.body).to include(I18n.t("soap_notes.index_title"))
      expect(response.body).to include(I18n.t("complementary_informations.index_title"))
    end

    it "offers a promote action from the briefing" do
      expect {
        post transition_patient_path(patient, event: "assess")
      }.to change { patient.reload.state }.from("interested").to("candidate")
    end

    it "handles a study with no criteria profile" do
      get patient_briefing_path(patient)
      expect(response).to be_successful
      expect(response.body).to include(I18n.t("patient_briefings.no_profile"))
    end
  end

  describe "row-level scoping for a trial centre rep" do
    let(:branch_a) { FactoryBot.create(:trial_center_branch) }
    let(:branch_b) { FactoryBot.create(:trial_center_branch) }
    let(:study_a) { FactoryBot.create(:study).tap { |s| s.trial_center_branches << branch_a } }
    let(:study_b) { FactoryBot.create(:study).tap { |s| s.trial_center_branches << branch_b } }
    let!(:mine) { FactoryBot.create(:patient, study: study_a) }
    let!(:theirs) { FactoryBot.create(:patient, study: study_b) }

    before do
      rep = FactoryBot.create(:user, userable: FactoryBot.create(:trial_center_branch_rep, trial_center_branch: branch_a))
      sign_in(rep, scope: :user)
    end

    it "reaches its own centre's patient briefing" do
      get patient_briefing_path(mine)
      expect(response).to be_successful
    end

    it "404s on another centre's patient briefing" do
      get patient_briefing_path(theirs)
      expect(response).to have_http_status(:not_found)
    end
  end

  it "requires authentication" do
    get patient_briefing_path(patient)
    expect(response).to redirect_to(new_user_session_path)
  end
end
