require 'rails_helper'

# The public self-report questionnaire — step 2 of "¡Quiero participar!".
# The patient's identity comes from the session stamp step 1 wrote; nothing is
# read from params. What the patient submits becomes DECLARATIONS (testimony),
# never VariableValues (the investigator-verified gate inputs) — and if the
# declarations satisfy every primary criterion, the patient is auto-triaged
# interested → candidate with a system whodunnit.
RSpec.describe "Self reports (public questionnaire)", type: :request do
  let(:study) { FactoryBot.create(:study, patient_self_report_enabled: true) }
  let(:profile) { FactoryBot.create(:criteria_profile, study: study) }
  let!(:age) do
    profile.criteria_variables.create!(
      name: "Edad", variable_type: "inclusion", value_type: "quantitative",
      comparison_type: "between_range", reference_value_1: 18, reference_value_2: 40,
      criteria_category: "basic", patient_prompt: "¿Cuál es su edad en años?"
    )
  end
  let!(:secret_rule) do
    # No patient_prompt: must never be asked, and its thresholds must never leak.
    profile.criteria_variables.create!(
      name: "Puntuación PASI", variable_type: "inclusion", value_type: "quantitative",
      comparison_type: "more_than_or_equal", reference_value_1: 20,
      criteria_category: "specific"
    )
  end

  def submit_participation(extra = {})
    post participation_requests_path(study_id: study.id), params: {
      patient: { contact_number: "+57 300 123 4567", data_processing_authorization: "1",
                 adult_confirmed: "1" }.merge(extra)
    }
  end

  # A SPECIFIC rule that DOES carry a prompt — asked since 2026-10-04. The pair
  # (secret_rule, this one) separates the two reasons a rule can go unasked: no
  # prompt at all vs. a prompt somebody wrote. Only the first silences a rule now.
  let!(:prompted_specific) do
    profile.criteria_variables.create!(
      name: "Duración de la enfermedad", variable_type: "inclusion",
      value_type: "quantitative", comparison_type: "more_than_or_equal",
      reference_value_1: 6, criteria_category: "specific",
      patient_prompt: "¿Hace cuántos meses aparecieron los síntomas?"
    )
  end

  describe "which criteria become questions" do
    before do
      submit_participation
      get study_self_report_path(study)
    end

    it "asks the basic criteria" do
      expect(response.body).to include("¿Cuál es su edad en años?")
    end

    # Flipped deliberately on 2026-10-04. It was basic-only on the reasoning
    # that a specific criterion "cannot move the outcome", which expired when
    # the specific tier became a gate: specific answers now decide the step to
    # `potential` and carry the count that orders a rep's queue. Asking the ones
    # a patient can actually speak to is how that queue gets filled while we
    # still have their attention.
    it "asks a specific criterion too, when somebody wrote it a prompt" do
      expect(response.body).to include("¿Hace cuántos meses aparecieron los síntomas?")
    end

    it "still never asks a rule nobody wrote a prompt for" do
      expect(response.body).not_to include("Puntuación PASI")
    end

    it "leaks neither the rule names nor their thresholds" do
      expect(response.body).not_to include("Puntuación PASI")
      expect(response.body).not_to include("Duración de la enfermedad")
      expect(response.body).not_to match(/\b20\b.*PASI|PASI.*\b20\b/)
    end
  end

  describe "the step-1 handoff" do
    it "redirects into the questionnaire when the study enables self-report" do
      submit_participation

      expect(response).to redirect_to(study_self_report_path(study))
      follow_redirect!
      expect(response).to be_successful
      expect(response.body).to include("¿Cuál es su edad en años?")
    end

    it "goes straight to thanks when the study has the switch off" do
      study.update!(patient_self_report_enabled: false)
      submit_participation

      expect(response).to redirect_to(study_about_path(study))
    end

    it "refuses without the adult confirmation, writing nothing" do
      expect {
        post participation_requests_path(study_id: study.id), params: {
          patient: { contact_number: "+57 300 123 4567", data_processing_authorization: "1" }
        }
      }.not_to change(Patient, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "records the proxy declaration on the patient" do
      submit_participation(submitted_by_proxy: "1")

      expect(Patient.last.submitted_by_proxy).to be true
    end
  end

  describe "the questionnaire" do
    before { submit_participation }

    let(:patient) { Patient.order(:id).last }

    it "renders only patient prompts — never rule names, summaries or thresholds" do
      get study_self_report_path(study)

      expect(response.body).to include("¿Cuál es su edad en años?")
      expect(response.body).not_to include("Puntuación PASI") # promptless rule not asked
      expect(response.body).not_to include("entre 18 y 40")   # rule_summary never leaks
      expect(response.body).not_to include("Edad")            # internal rule name never leaks
    end

    it "saves answers as declarations, never as variable values" do
      expect {
        post study_self_report_path(study), params: { answers: { age.id.to_s => "30" } }
      }.to change(PatientDeclaration, :count).by(1)
         .and change(VariableValue, :count).by(0)

      declaration = patient.patient_declarations.live.sole
      expect(declaration.answer).to eq("30")
      expect(declaration.prompt).to eq("¿Cuál es su edad en años?")
      expect(declaration.recorded_by).to be_nil # self-entered
      expect(declaration.capture_mode).to eq("public_form")
    end

    it "records the self-report consent, and the future-studies one only when ticked" do
      post study_self_report_path(study), params: { answers: { age.id.to_s => "30" } }
      types = patient.consents.pluck(:document_type)
      expect(types).to include(Consent::SELF_REPORT_QUESTIONNAIRE)
      expect(types).not_to include(Consent::FUTURE_STUDIES)
    end

    it "records the optional future-studies consent when authorized" do
      post study_self_report_path(study),
           params: { answers: { age.id.to_s => "30" }, future_studies_authorization: "1" }

      expect(patient.consents.pluck(:document_type)).to include(Consent::FUTURE_STUDIES)
    end

    it "auto-triages to candidate when every basic criterion complies, attributed to the system" do
      post study_self_report_path(study), params: { answers: { age.id.to_s => "30" } }

      expect(patient.reload.state).to eq("candidate")
      version = patient.versions.last
      expect(version.whodunnit).to eq(Patient::SYSTEM_WHODUNNIT)
    end

    # The questionnaire produces declarations, never VariableValues, and the
    # step into `potential` reads only VariableValues — so no amount of
    # self-reporting can reach it. This is the whole point of the two tiers.
    it "never carries a patient past candidate, however complete the answers" do
      post study_self_report_path(study), params: { answers: { age.id.to_s => "30" } }

      expect(patient.reload.state).to eq("candidate")
      expect(patient.may_accept?).to be false
    end

    it "stays interested when the declaration fails the rule" do
      post study_self_report_path(study), params: { answers: { age.id.to_s => "55" } }

      expect(patient.reload.state).to eq("interested")
    end

    it "stays interested on a declined answer and stores the 'No sé'" do
      post study_self_report_path(study), params: { declined: { age.id.to_s => "1" } }

      expect(patient.reload.state).to eq("interested")
      expect(patient.patient_declarations.live.sole.declined).to be true
    end

    # NARROWED 2026-08-25, deliberately. The confirmation now says whether the
    # study looks like a match at all — answering five questions into silence
    # was its own harm — but it still never names a criterion. What follows
    # pins exactly where that line now sits.
    it "confirms plainly when the answers look like a match" do
      post study_self_report_path(study), params: { answers: { age.id.to_s => "30" } }

      expect(flash[:notice]).to eq(I18n.t("self_reports.thanks"))
      follow_redirect!
      expect(response.body).not_to include(I18n.t("criteria_assessments.eligible"))
    end

    it "says the study is not a match, without saying which criterion" do
      post study_self_report_path(study), params: { answers: { age.id.to_s => "9" } }

      expect(flash[:notice]).to eq(I18n.t("self_reports.not_a_match"))
      # The threshold could only leak through the message itself; the page it
      # redirects to is full of unrelated digits (asset digests, dates), so a
      # bare `not_to include("18")` over the body proves nothing.
      expect(flash[:notice]).not_to include("18")
      expect(flash[:notice]).not_to include(age.name)

      follow_redirect!
      expect(response.body).not_to include(age.name)
      expect(response.body).not_to include(age.rule_summary.to_s)
    end

    # The two must be indistinguishable from outside: a patient who did not
    # answer enough learns exactly as much as one who measurably does not
    # qualify, which is nothing beyond "not a match for now".
    it "gives an incomplete questionnaire the SAME message as a failing one" do
      post study_self_report_path(study), params: { answers: {} }

      expect(flash[:notice]).to eq(I18n.t("self_reports.not_a_match"))
    end

    it "still never names a criterion, whatever the outcome" do
      post study_self_report_path(study), params: { answers: { age.id.to_s => "9" } }

      expect(I18n.t("self_reports.not_a_match")).not_to include(age.name)
      expect(I18n.t("self_reports.not_a_match")).not_to match(/\d/)
    end

    it "stores the reported city when picked from the list, ignoring free-typed values" do
      post study_self_report_path(study),
           params: { answers: {}, reported_city: "Bucaramanga" }
      expect(patient.reload.reported_city).to eq("Bucaramanga")

      submit_participation
      other = Patient.order(:id).last
      post study_self_report_path(study),
           params: { answers: {}, reported_city: "<script>alert(1)</script>" }
      expect(other.reload.reported_city).to be_nil
    end

    it "supersedes rather than overwrites on re-answer" do
      post study_self_report_path(study), params: { answers: { age.id.to_s => "55" } }

      submit_participation # fresh session stamp for the same... creates a new patient
      # Re-answering as the SAME patient needs the same session; simulate by
      # re-entering through the questionnaire again for the new patient instead.
      newest = Patient.order(:id).last
      post study_self_report_path(study), params: { answers: { age.id.to_s => "30" } }

      expect(newest.patient_declarations.live.sole.answer).to eq("30")
    end

    it "rejects more files than the cap, saving nothing" do
      files = Array.new(Patient::MAX_SELF_REPORTED_FILES + 1) do
        Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4 fake"), "application/pdf", original_filename: "exam.pdf")
      end

      post study_self_report_path(study), params: { answers: {}, files: files }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(patient.reload.self_reported_files.count).to eq(0)
    end

    it "attaches valid files within the cap" do
      file = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4 fake"), "application/pdf", original_filename: "exam.pdf")

      post study_self_report_path(study), params: { answers: {}, files: [ file ] }

      expect(patient.reload.self_reported_files.count).to eq(1)
    end
  end


  # The exclusions, stated to EVERYONE before any answer is given (2026-08-25).
  # This is what makes the silent no-verdict rule survivable: a person can rule
  # themselves out honestly instead of answering five questions into the void.
  # It is not feedback, so it is not the oracle the rule exists to prevent.
  # Who is responsible for what, before a single answer is given.
  #
  # Written as a statement of roles rather than a waiver on purpose: Ley 1480
  # de 2011 Art. 43 voids a clause limiting our own liability (nº 1) or shifting
  # it to a third party outside the relationship (nº 5), so an "exoneration"
  # would be struck out and would have bought nothing. What the page says
  # instead is where responsibility already sits — and that it does NOT move
  # because a regulator authorized the trial.
  # The line that does NOT move, now that specific criteria can be asked: a
  # declaration is testimony, never a measurement. Answering every specific
  # question perfectly still leaves the clinical gate shut, because
  # `criteria_met_for_potential?` reads investigator VariableValues and a
  # questionnaire writes PatientDeclarations.
  describe "a specific criterion answered by the patient" do
    before { submit_participation }

    it "is stored as a declaration, never as a scorable value" do
      post study_self_report_path(study), params: { answers: { prompted_specific.id.to_s => "12" } }

      patient = Patient.last
      expect(patient.patient_declarations.live.map(&:criteria_variable_id)).to include(prompted_specific.id)
      expect(patient.variable_values).to be_empty
    end

    it "cannot open the step to potential, however well it is answered" do
      post study_self_report_path(study),
           params: { answers: { age.id.to_s => "30", prompted_specific.id.to_s => "12" } }

      patient = Patient.last.reload
      expect(patient.state).to eq("candidate")
      expect(patient.criteria_met_for_potential?).to be false
      expect(patient.may_accept?).to be false
    end

    # What it DOES do: fill the count a rep sorts the queue by, on the
    # self-report side, which is the whole point of asking.
    it "counts toward the declared specific score the rep sees" do
      post study_self_report_path(study),
           params: { answers: { age.id.to_s => "30", prompted_specific.id.to_s => "12" } }

      declared = Patient.last.reload.self_report_result
      expect(declared.specific_score).to eq(1)
      expect(declared.specific_total_count).to eq(2)
    end
  end

  describe "the responsibility disclaimer" do
    # Step 1 writes the session stamp this page reads; without it the request
    # redirects to root and the body is empty.
    before { submit_participation }

    it "is shown before any question is answered" do
      get study_self_report_path(study)

      %w[heading role responsibility insurance no_enrollment not_medical_advice].each do |key|
        expect(response.body).to include(ERB::Util.html_escape(I18n.t("self_reports.disclaimer.#{key}")))
      end
    end

    it "is the first thing on the page, ahead of the questions and the exclusions" do
      get study_self_report_path(study)

      disclaimer = response.body.index(ERB::Util.html_escape(I18n.t("self_reports.disclaimer.heading")))
      why = response.body.index(ERB::Util.html_escape(I18n.t("self_reports.why_it_matters")))
      question = response.body.index(ERB::Util.html_escape(age.patient_prompt))

      expect(disclaimer).to be < why
      expect(disclaimer).to be < question
    end

    # The whole point is naming where responsibility sits. A text that said only
    # "Medici is not responsible" would be the void kind.
    it "names the parties that carry it, and says a regulator's sign-off does not move it" do
      get study_self_report_path(study)
      body = response.body

      expect(body).to include("patrocinador")
      expect(body).to include("investigador")
      expect(body).to include(ERB::Util.html_escape("Resolución 2378 de 2008"))
      expect(body).to include(ERB::Util.html_escape("comité de ética"))
    end

    it "renders in every language without a missing translation" do
      I18n.available_locales.each do |locale|
        %w[heading role responsibility insurance no_enrollment not_medical_advice].each do |key|
          expect { I18n.t!("self_reports.disclaimer.#{key}", locale: locale) }
            .not_to raise_error, "self_reports.disclaimer.#{key} missing in #{locale}"
        end
      end
    end
  end

  describe "the exclusions shown upfront" do
    let!(:pregnancy) do
      profile.criteria_variables.create!(
        name: "Embarazo o lactancia", variable_type: "exclusion", value_type: "boolean",
        comparison_type: "true", criteria_category: "basic",
        patient_prompt: "¿Estás embarazada o en período de lactancia?"
      )
    end

    before { submit_participation }

    it "lists them as statements, from the approved patient wording" do
      get study_self_report_path(study)

      expect(response.body).to include(I18n.t("self_reports.exclusions_heading"))
      expect(response.body).to include("estás embarazada o en período de lactancia")
    end

    it "still never renders the rule name or its thresholds" do
      get study_self_report_path(study)

      expect(response.body).not_to include(pregnancy.name)
      expect(response.body).not_to include(age.name)
      expect(response.body).not_to include(age.rule_summary.to_s)
    end

    # Only exclusions. "You must be between 18 and 75" is a threshold, and
    # thresholds are protocol — an inclusion listed here would leak one.
    it "does not list the inclusions" do
      get study_self_report_path(study)

      heading = I18n.t("self_reports.exclusions_heading")
      block = response.body[response.body.index(heading)..]
      list = block[0, block.index("</ul>").to_i + 5]

      expect(list).to include("embarazada")
      expect(list).not_to include(age.patient_prompt.to_s.delete_prefix("¿").delete_suffix("?"))
    end
  end
  describe "session discipline" do
    it "bounces to root with no session stamp — identity never comes from params" do
      get study_self_report_path(study)
      expect(response).to redirect_to(root_path)
    end

    it "one submission consumes the stamp" do
      submit_participation
      post study_self_report_path(study), params: { answers: { age.id.to_s => "30" } }

      get study_self_report_path(study)
      expect(response).to redirect_to(root_path)
    end
  end
end
