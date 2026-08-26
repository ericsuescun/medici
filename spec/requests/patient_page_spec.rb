require 'rails_helper'

# The patient page carries BOTH halves of the record since 2026-08-24:
# demographics on the left, the clinical/eligibility picture on the right. It
# used to be two pages (patients#show + patient_briefings#show) and a rep had to
# bounce between them to answer one question.
RSpec.describe "Patient page (demographic + clinical)", type: :request do
  let(:study) { FactoryBot.create(:study) }
  let(:patient) { FactoryBot.create(:patient, study: study, contact_number: "+57 300 123 4567") }
  let(:profile) { FactoryBot.create(:criteria_profile, study: study) }

  def primary_rule!(name:, category: "primary")
    profile.criteria_variables.create!(
      name: name, variable_type: "inclusion", value_type: "quantitative",
      comparison_type: "between_range", reference_value_1: 18, reference_value_2: 40,
      criteria_category: category
    )
  end

  describe "as an admin" do
    before { sign_in(FactoryBot.create(:user, :admin), scope: :user) }

    it "shows the demographic and the clinical sections side by side" do
      cv = primary_rule!(name: "Edad")
      patient.variable_values.create!(criteria_variable: cv, name: "Edad", value: "50",
                                      value_type: "quantitative", comparison_type: "between_range")

      get patient_path(patient)

      expect(response).to be_successful
      expect(response.body).to include(I18n.t("patients.sections.demographic"))
      expect(response.body).to include(I18n.t("patients.sections.clinical"))
      expect(response.body).to include(I18n.t("criteria_assessments.not_eligible"))
      expect(response.body).to include(I18n.t("complementary_informations.index_title"))
    end

    # The old briefing listed only the failing and pending criteria, so a rep
    # could not see what a patient actually PASSED without opening the form.
    it "lists every criterion and its answer, primary before secondary" do
      passing = primary_rule!(name: "Criterio primario")
      secondary = primary_rule!(name: "Criterio secundario", category: "secondary")
      patient.variable_values.create!(criteria_variable: passing, name: passing.name, value: "30",
                                      value_type: "quantitative", comparison_type: "between_range")
      patient.variable_values.create!(criteria_variable: secondary, name: secondary.name, value: "25",
                                      value_type: "quantitative", comparison_type: "between_range")

      get patient_path(patient)

      body = response.body
      expect(body).to include("Criterio primario")
      expect(body).to include("Criterio secundario")
      # A passing criterion is visible, not just the problems.
      expect(body).to include(I18n.t("criteria_assessments.pass"))
      # Primary block first.
      expect(body.index("Criterio primario")).to be < body.index("Criterio secundario")
    end

    it "marks an unmeasured criterion as no-data rather than as a failure" do
      primary_rule!(name: "Sin medir")

      get patient_path(patient)

      expect(response.body).to include(I18n.t("criteria_assessments.no_data"))
    end

    it "offers the promote action" do
      expect {
        post transition_patient_path(patient, event: "assess")
      }.to change { patient.reload.state }.from("interested").to("candidate")
    end

    # A participant is at the end of the line, so the take-action box has nothing
    # to promote to. It used to fall through to promotion advice — "no cumple
    # todos los criterios... antes de promover" — on the strength of the
    # WHOLE-PROTOCOL verdict, which a secondary criterion alone can fail. Beside
    # the lone "Rechazar" button that read as a recommendation to reject a
    # patient whose primary criteria all pass.
    context "when the patient is already at the end of the lifecycle" do
      before { patient.update!(state: "participant") }

      it "names the way back instead of offering advice about promoting" do
        get patient_path(patient)

        expect(response.body).to include(
          ERB::Util.html_escape(
            I18n.t("criteria_assessments.brief.at_final_state",
                   state: I18n.t("patients.states.participant"),
                   back_event: I18n.t("patients.reject"),
                   back_to: I18n.t("patients.states.candidate"))
          )
        )
        expect(response.body).not_to include(I18n.t("criteria_assessments.brief.promote_hint_not_eligible"))
        expect(response.body).not_to include(I18n.t("criteria_assessments.brief.promote_hint_incomplete"))
      end
    end

    it "handles a study with no criteria profile" do
      get patient_path(patient)

      expect(response).to be_successful
      expect(response.body).to include(I18n.t("patient_briefings.no_profile"))
    end

    it "redirects the retired briefing URL to the patient page" do
      get patient_briefing_path(patient)

      expect(response).to redirect_to(patient_path(patient))
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

    it "reaches its own centre's patient" do
      get patient_path(mine)
      expect(response).to be_successful
    end

    # 404 rather than 403: a 403 would confirm the record exists, which is
    # itself a disclosure about an identifiable person.
    it "404s on another centre's patient" do
      get patient_path(theirs)
      expect(response).to have_http_status(:not_found)
    end
  end

  # App-wide behaviour for every SecureApplicationController page (verified
  # against /studies too): an anonymous request is bounced to root rather than
  # to the sign-in form, because the Pundit authorization runs and raises before
  # Devise gets to redirect. What matters here is that the page never renders.
  it "never serves the page to an anonymous visitor" do
    get patient_path(patient)

    expect(response).to have_http_status(:found)
    expect(response).to redirect_to(root_path)
  end
end
