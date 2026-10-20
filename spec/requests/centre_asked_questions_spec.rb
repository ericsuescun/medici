require 'rails_helper'

# A SPECIFIC question can be switched off the public questionnaire
# (`CriteriaVariable#asked_online`) so the centre asks it instead, by phone or in
# consultation, and records the answer in the assessment. Basic questions are
# always asked online — auto-triage needs a declaration for each of them — so
# the form does not offer them the switch. Added 2026-10-19 (the column was the
# never-read `shown`).
RSpec.describe "Questions the centre asks instead of the questionnaire", type: :request do
  let(:study) { FactoryBot.create(:study, patient_self_report_enabled: true) }
  let(:profile) { FactoryBot.create(:criteria_profile, study: study) }
  let!(:age) do
    profile.criteria_variables.create!(
      name: "Edad", variable_type: "inclusion", value_type: "quantitative",
      comparison_type: "between_range", reference_value_1: 18, reference_value_2: 40,
      criteria_category: "basic", patient_prompt: "¿Cuál es su edad en años?"
    )
  end
  let!(:online_specific) do
    profile.criteria_variables.create!(
      name: "Duración de la enfermedad", variable_type: "inclusion", value_type: "quantitative",
      comparison_type: "more_than_or_equal", reference_value_1: 6, criteria_category: "specific",
      patient_prompt: "¿Hace cuántos meses aparecieron los síntomas?"
    )
  end
  let!(:centre_asked) do
    profile.criteria_variables.create!(
      name: "Consumo de sustancias", variable_type: "exclusion", value_type: "boolean",
      comparison_type: "true", criteria_category: "specific", asked_online: false,
      patient_prompt: "¿Consume alguna sustancia psicoactiva?"
    )
  end

  describe "the public questionnaire" do
    before do
      post participation_requests_path(study_id: study.id), params: {
        patient: { contact_number: "+57 300 123 4567", data_processing_authorization: "1", adult_confirmed: "1" }
      }
    end

    it "asks the specific questions still switched on, and not the one the centre asks" do
      post study_self_report_path(study), params: { answers: { age.id.to_s => "30" } }
      follow_redirect!

      expect(response.body).to include("¿Hace cuántos meses aparecieron los síntomas?")
      expect(response.body).not_to include("¿Consume alguna sustancia psicoactiva?")
    end

    it "ends on page 1 when every specific question is the centre's to ask" do
      online_specific.update!(asked_online: false)

      post study_self_report_path(study), params: { answers: { age.id.to_s => "30" } }

      expect(response).to redirect_to(study_about_path(study))
      expect(flash[:notice]).to eq(I18n.t("self_reports.thanks"))
    end
  end

  context "signed in as an admin" do
    before { sign_in(FactoryBot.create(:user, :admin), scope: :user) }

    it "gives the rep the question to ask on the assessment page" do
      patient = FactoryBot.create(:patient, study: study)

      get patient_criteria_assessment_path(patient, criteria_profile_id: profile.id)

      expect(response.body).to include(ERB::Util.html_escape(I18n.t("criteria_assessments.capture.ask_it")))
      expect(response.body).to include("¿Consume alguna sustancia psicoactiva?")
    end

    it "marks the question as the centre's in the rule tables" do
      get criteria_profile_criteria_variables_path(profile)

      expect(response.body).to include(I18n.t("criteria_variables.form.asked_by_centre_note"))
    end

    it "offers the switch on a specific rule and hides it on a basic one" do
      get edit_criteria_profile_criteria_variable_path(profile, centre_asked)
      switch = Nokogiri::HTML(response.body).at_css('[data-specific-only-target="specificOnly"]')
      expect(switch["hidden"]).to be_nil

      get edit_criteria_profile_criteria_variable_path(profile, age)
      switch = Nokogiri::HTML(response.body).at_css('[data-specific-only-target="specificOnly"]')
      expect(switch["hidden"]).not_to be_nil
    end

    it "saves the switch on a specific rule" do
      patch criteria_profile_criteria_variable_path(profile, online_specific),
            params: { criteria_variable: { asked_online: "0" } }

      expect(online_specific.reload.asked_online).to be(false)
    end

    it "ignores the switch on a basic rule, even if the request sends it" do
      patch criteria_profile_criteria_variable_path(profile, age),
            params: { criteria_variable: { asked_online: "0" } }

      expect(age.reload.asked_online).to be(true)
    end
  end
end
