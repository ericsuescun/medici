require 'rails_helper'

RSpec.describe "Criteria assessments", type: :request do
  # The profile belongs to the patient's OWN study — the only arrangement the
  # controller accepts, and the one the app actually links to. (These used to be
  # two unrelated studies, which meant the page evaluated one rule set while
  # Patient#primary_criteria_met? gated on another.)
  let(:study) { FactoryBot.create(:study) }
  let(:patient) { FactoryBot.create(:patient, study: study) }
  let(:profile) { FactoryBot.create(:criteria_profile, study: study) }
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

    it "snapshots how decisive the rule was onto the captured value" do
      patch assessment_path, params: { values: { age.id.to_s => "30" } }

      expect(patient.variable_values.find_by(name: "Edad").criteria_category).to eq("primary")
    end

    describe "the recruitment score" do
      let!(:height) do
        profile.criteria_variables.create!(
          name: "Talla", variable_type: "inclusion", value_type: "quantitative",
          comparison_type: "more_than", reference_value_1: 150, criteria_category: "secondary"
        )
      end

      it "is computed from the primary criteria only, and a failing secondary does not lower it" do
        patch assessment_path, params: { values: { age.id.to_s => "30", height.id.to_s => "140" } }
        get assessment_path

        expect(response.body).to include("Puntaje de reclutamiento")
        expect(response.body).to include("100%")
        expect(response.body).to include("Listo para promover")
        # ...while the secondary failure is still reported, not hidden.
        expect(response.body).to include("no se cumple")
      end

      it "reports a decisive criterion left unmeasured as still assessing" do
        patch assessment_path, params: { values: { height.id.to_s => "170" } }
        get assessment_path

        expect(response.body).to include("0%")
        expect(response.body).to include("En evaluación")
      end

      # A patient held up only by a complementary criterion must not be
      # headlined "not eligible" — that is a warning, and the copy has to say
      # SECONDARY so nobody reads it as a verdict.
      it "warns about an unmet secondary criterion instead of calling the patient ineligible" do
        patch assessment_path, params: { values: { age.id.to_s => "30", height.id.to_s => "140" } }
        get assessment_path

        expect(response.body).to include(I18n.t("criteria_assessments.secondary_warning.title"))
        expect(response.body).to include(I18n.t("criteria_assessments.eligible"))
        expect(response.body).not_to include(I18n.t("criteria_assessments.primary.not_eligible_detail", count: 1))
      end

      it "separates the capture form into primary and secondary sections" do
        get assessment_path

        expect(response.body).to include("Criterios primarios")
        expect(response.body).to include("Criterios secundarios")
        expect(response.body.index("Criterios primarios")).to be < response.body.index("Criterios secundarios")
      end
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

    it "offers a promote action once the primary criterion is recorded and met" do
      patch assessment_path, params: { values: { age.id.to_s => "30" } }

      expect {
        post transition_patient_path(patient, event: "assess")
      }.to change { patient.reload.state }.from("interested").to("candidate")
    end

    it "refuses the promote action while the primary criterion is unrecorded" do
      expect {
        post transition_patient_path(patient, event: "assess")
      }.not_to change { patient.reload.state }
    end
  end

  # The criteria gate applies, so the forward step is locked rather than offered.
  context "when the study's criteria gate the patient" do
    before { sign_in(FactoryBot.create(:user, :admin), scope: :user) }

    it "locks the forward step and explains what is required" do
      get assessment_path

      expect(response).to be_successful
      expect(response.body).to include(I18n.t("criteria_assessments.locked.hint"))
      expect(response.body).to include("bi-lock-fill")
    end

    it "unlocks it once the primary criterion is recorded and met" do
      patch assessment_path, params: { values: { age.id.to_s => "30" } }
      get assessment_path

      expect(response.body).not_to include("bi-lock-fill")
      expect(response.body).to include(I18n.t("criteria_assessments.score.recommendation.ready"))
    end
  end

  # This page is the ONLY write surface for the values the promotion gate reads,
  # so an unscoped load here would let a rep with no authority over the patient
  # forge the gate's inputs and have the patient's own rep promote them.
  describe "row-level scoping for a trial centre rep" do
    let(:branch_a) { FactoryBot.create(:trial_center_branch) }
    let(:branch_b) { FactoryBot.create(:trial_center_branch) }
    let(:study_a) { FactoryBot.create(:study).tap { |s| s.trial_center_branches << branch_a } }
    let(:study_b) { FactoryBot.create(:study).tap { |s| s.trial_center_branches << branch_b } }
    let(:profile_a) { FactoryBot.create(:criteria_profile, study: study_a) }
    let(:profile_b) { FactoryBot.create(:criteria_profile, study: study_b) }
    let!(:mine) { FactoryBot.create(:patient, study: study_a) }
    let!(:theirs) { FactoryBot.create(:patient, study: study_b) }
    let!(:their_rule) do
      profile_b.criteria_variables.create!(
        name: "Edad", variable_type: "inclusion", value_type: "quantitative",
        comparison_type: "between_range", reference_value_1: 18, reference_value_2: 40
      )
    end

    before do
      profile_a # instantiate so the rep's own patient has a profile to assess
      rep = FactoryBot.create(:user, userable: FactoryBot.create(:trial_center_branch_rep, trial_center_branch: branch_a))
      sign_in(rep, scope: :user)
    end

    it "reaches its own centre's patient assessment" do
      get patient_criteria_assessment_path(mine, criteria_profile_id: profile_a.id)
      expect(response).to be_successful
    end

    it "404s reading another centre's patient assessment" do
      get patient_criteria_assessment_path(theirs, criteria_profile_id: profile_b.id)
      expect(response).to have_http_status(:not_found)
    end

    it "404s writing another centre's patient values, so the gate's inputs cannot be forged" do
      expect {
        patch patient_criteria_assessment_path(theirs, criteria_profile_id: profile_b.id),
              params: { values: { their_rule.id.to_s => "30" } }
      }.not_to change { theirs.variable_values.count }

      expect(response).to have_http_status(:not_found)
      expect(theirs.reload.may_assess?).to be false
    end

    it "refuses a profile that is not the patient's own study's" do
      get patient_criteria_assessment_path(mine, criteria_profile_id: profile_b.id)
      expect(response).to have_http_status(:not_found)
    end
  end

  context "as a patient (cannot edit patients)" do
    before { sign_in(FactoryBot.create(:user, :patient), scope: :user) }

    # 404, not 403: the patient is loaded through `policy_scope` now, so a user
    # with no patient access cannot find the record at all — the same deliberate
    # choice the rest of the patient surfaces make, since a 403 would confirm
    # that an identifiable person's record exists.
    it "is blocked" do
      get assessment_path
      expect(response).to have_http_status(:not_found)
    end
  end
end
