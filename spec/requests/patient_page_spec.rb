require 'rails_helper'

# The patient page carries BOTH halves of the record since 2026-08-24:
# demographics on the left, the clinical/eligibility picture on the right. It
# used to be two pages (patients#show + patient_briefings#show) and a rep had to
# bounce between them to answer one question.
RSpec.describe "Patient page (demographic + clinical)", type: :request do
  let(:study) { FactoryBot.create(:study) }
  let(:patient) { FactoryBot.create(:patient, study: study, contact_number: "+57 300 123 4567") }
  let(:profile) { FactoryBot.create(:criteria_profile, study: study) }

  def primary_rule!(name:, category: "basic")
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
      secondary = primary_rule!(name: "Criterio secundario", category: "specific")
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

    # Found 2026-10-06 walking the two-page questionnaire by hand: a patient who
    # reached Candidato on their own answers opened to "Evaluación incompleta —
    # faltan 5 criterios básicos por registrar" and a row of zeros, with nothing
    # on the page saying why they were a candidate at all. The clinical column
    # read only what the centre recorded. Both halves of the evidence are shown
    # now — labelled, side by side, and never added together.
    describe "a patient who answered the questionnaire" do
      let!(:age) { primary_rule!(name: "Edad") }
      let!(:visits) do
        profile.criteria_variables.create!(
          name: "Visitas", variable_type: "inclusion", value_type: "boolean",
          comparison_type: "true", criteria_category: "specific"
        )
      end

      before do
        [ [ age, "30" ], [ visits, "true" ] ].each do |cv, answer|
          patient.patient_declarations.create!(
            criteria_variable: cv, prompt: "¿?", answer: answer, value_type: cv.value_type,
            capture_mode: "public_form", declared_at: Time.current
          )
        end
        patient.sync_state_with_criteria!
      end

      def row_for(body, name)
        body.scan(%r{<tr>.*?</tr>}m).find { |row| row.include?("<td>#{name}</td>") }
      end

      it "says what the patient declared, and what that does and does not unlock" do
        get patient_path(patient)
        body = CGI.unescapeHTML(response.body)

        expect(patient.reload.state).to eq("candidate")
        expect(body).to include(I18n.t("criteria_assessments.self_report.title"))
        expect(body).to include(I18n.t("criteria_assessments.self_report.basic", met: 1, total: 1))
        expect(body).to include(I18n.t("criteria_assessments.self_report.specific", met: 1, total: 1))
      end

      it "labels the verdict and the counts as what the centre recorded" do
        get patient_path(patient)
        body = CGI.unescapeHTML(response.body)
        heading = I18n.t("criteria_assessments.recorded_heading")

        expect(body).to include(heading)
        expect(body.index(heading)).to be < body.index(I18n.t("criteria_assessments.incomplete"))
      end

      it "shows each declared answer beside the recorded one" do
        get patient_path(patient)
        body = CGI.unescapeHTML(response.body)

        expect(body).to include(I18n.t("criteria_assessments.declared_column"))
        expect(row_for(body, "Edad")).to match(%r{class="declared-value[^"]*">30</span>})
        # In words, not the stored "true" — and in the declared cell itself: the
        # Regla column of a Sí/No rule says "Sí" too, so the row alone proves nothing.
        expect(row_for(body, "Visitas")).to match(%r{class="declared-value[^"]*">#{I18n.t('common.yes')}</span>})
        expect(row_for(body, "Visitas")).not_to include(">true<")
      end

      it "keeps the declared verdict apart from the answer, so «No» and «Cumple» never read as one" do
        get patient_path(patient)
        row = row_for(CGI.unescapeHTML(response.body), "Visitas")
        between = row[row.index("declared-value")...row.index("declared-verdict")]

        expect(row).to include(%(class="declared-verdict ms-auto))
        expect(between).to include("</div>")
      end

      it "carries the same summary on the assessment page" do
        get patient_criteria_assessment_path(patient)

        expect(CGI.unescapeHTML(response.body))
          .to include(I18n.t("criteria_assessments.self_report.basic", met: 1, total: 1))
      end
    end

    it "shows no declared summary or column for a patient who never answered" do
      primary_rule!(name: "Edad")

      get patient_path(patient)

      expect(response.body).not_to include(I18n.t("criteria_assessments.self_report.title"))
      expect(response.body).not_to include(I18n.t("criteria_assessments.declared_column"))
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
      before { patient.update!(state: "potential") }

      it "names the way back instead of offering advice about promoting" do
        get patient_path(patient)

        expect(response.body).to include(
          ERB::Util.html_escape(
            I18n.t("criteria_assessments.brief.at_final_state",
                   state: I18n.t("patients.states.potential"),
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
