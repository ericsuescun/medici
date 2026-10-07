require "rails_helper"
require Rails.root.join("db/seeds/self_report_scenario")

# The hand-testing scenario (db/seeds/self_report_scenario.rb) prints a cheat
# sheet a person follows in a browser: which answer passes, what each message
# means, where each example patient should stand. A cheat sheet that has gone
# stale is worse than none — the tester blames the app — so every promise it
# makes is walked here through the real controllers.
#
# It has already paid for itself once: building the "Fede" example is how the
# demote/re-promote loop in Patient#sync_state_with_criteria! was found.
RSpec.describe "Self-report hand-testing scenario", type: :request do
  let!(:admin) { FactoryBot.create(:user, :admin) }
  let!(:built) { SelfReportScenario.build! }
  let(:study) { built[:study] }
  let(:profile) { built[:profile] }

  def rule(name) = profile.criteria_variables.find_by!(name: name)

  # The asked questions of one tier, each with its PASA value, then overrides.
  def passing_answers(category, overrides = {})
    SelfReportScenario::CRITERIA.select { |row| row[7] && row[0] == category }
                                .to_h { |row| [ rule(row[2]).id.to_s, row[8] ] }
                                .merge(overrides)
  end

  def start_participation
    post participation_requests_path(study_id: study.id), params: {
      patient: { firstname: "Prueba", contact_number: "+57 300 999 0000",
                 data_processing_authorization: "1", adult_confirmed: "1" }
    }
    Patient.order(:id).last
  end

  # Page 1, then page 2 if page 1 leads there — as a patient would.
  def submit_questionnaire(basic, specific = passing_answers("specific"))
    post study_self_report_path(study), params: { answers: basic }
    post study_self_report_more_path(study), params: { answers: specific } if response.redirect_url&.end_with?("/more")
    follow_redirect!
  end

  describe "the questionnaire" do
    before do
      start_participation
      get study_self_report_path(study)
    end

    it "asks the 5 basic questions on page 1 and the 4 prompted specific ones on page 2" do
      basic = SelfReportScenario::CRITERIA.select { |row| row[7] && row[0] == "basic" }
      specific = SelfReportScenario::CRITERIA.select { |row| row[7] && row[0] == "specific" }
      expect([ basic.size, specific.size ]).to eq([ 5, 4 ])

      basic.each { |row| expect(response.body).to include(ERB::Util.html_escape(row[7])) }
      specific.each { |row| expect(response.body).not_to include(ERB::Util.html_escape(row[7])) }

      post study_self_report_path(study), params: { answers: passing_answers("basic") }
      follow_redirect!
      specific.each { |row| expect(response.body).to include(ERB::Util.html_escape(row[7])) }
      basic.each { |row| expect(response.body).not_to include(ERB::Util.html_escape(row[7])) }
    end

    it "never asks the three clinic-measured rules, on either page" do
      unasked = SelfReportScenario::CRITERIA.reject { |row| row[7] }
      unasked.each { |row| expect(response.body).not_to include(ERB::Util.html_escape(row[2])) }

      post study_self_report_path(study), params: { answers: passing_answers("basic") }
      follow_redirect!
      unasked.each { |row| expect(response.body).not_to include(ERB::Util.html_escape(row[2])) }
    end

    it "offers the qualitative scale as a select on page 2" do
      post study_self_report_path(study), params: { answers: passing_answers("basic") }
      follow_redirect!

      SelfReportScenario::INTENSITY_SCALE.each do |option|
        expect(response.body).to include(">#{option}</option>")
      end
    end

    it "lists only the three basic exclusions upfront" do
      heading = I18n.t("self_reports.exclusions_heading")
      block = response.body[response.body.index(heading)..]
      list = block[0, block.index("</ul>")]

      expect(list.scan("<li>").size).to eq(3)
      expect(list).not_to include("opioides")
    end
  end

  describe "what the cheat sheet says happens on submit" do
    it "a) every basic answer passing → the thanks message, and candidate" do
      patient = start_participation
      submit_questionnaire(passing_answers("basic"))

      expect(response.body).to include(ERB::Util.html_escape(I18n.t("self_reports.thanks")))
      expect(patient.reload.state).to eq("candidate")
      expect(patient.self_report_result.specific_score).to eq(4)
      expect(patient.self_report_result.specific_total_count).to eq(7)
    end

    it "b) one basic answer failing → not a match on page 1, never shown page 2" do
      patient = start_participation
      post study_self_report_path(study),
           params: { answers: passing_answers("basic", rule("Embarazo o lactancia").id.to_s => "true") }

      expect(response).to redirect_to(study_about_path(study))
      follow_redirect!
      expect(response.body).to include(ERB::Util.html_escape(I18n.t("self_reports.not_a_match")))
      expect(patient.reload.state).to eq("interested")
    end

    it "c) one basic answer blank → the same message as (b), still interested" do
      patient = start_participation
      submit_questionnaire(passing_answers("basic", rule("Edad (años)").id.to_s => ""))

      expect(response.body).to include(ERB::Util.html_escape(I18n.t("self_reports.not_a_match")))
      expect(patient.reload.state).to eq("interested")
    end

    it "failing every specific answer still triages on the basic ones" do
      patient = start_participation
      failing = SelfReportScenario::CRITERIA.select { |row| row[0] == "specific" && row[7] }
                                            .to_h { |row| [ rule(row[2]).id.to_s, row[9] ] }
      submit_questionnaire(passing_answers("basic"), failing)

      expect(patient.reload.state).to eq("candidate")
    end
  end

  describe "the example patients" do
    it "each stand where EXAMPLES says they do" do
      SelfReportScenario::EXAMPLES.each do |spec|
        patient = Patient.find_by!(participant_code: spec[:code])
        expect(patient.state).to eq(spec[:expected]), "#{spec[:code]} is #{patient.state}"
      end
    end

    it "are not duplicated by a second build" do
      expect { SelfReportScenario.build! }.not_to change(Patient, :count)
    end

    it "come back to their starting states with reset" do
      ana = Patient.find_by!(participant_code: "PRUEBA-A")
      ana.discard!

      SelfReportScenario.build!(reset: true)

      expect(Patient.find_by!(participant_code: "PRUEBA-A").state).to eq("candidate")
    end

    it "print in the cheat sheet with no drift warning" do
      expect(SelfReportScenario.report(built)).not_to include("⚠")
    end
  end

  describe "the rep's side" do
    before { sign_in(built[:rep], scope: :user) }

    it "orders the candidates Dani, Ana, Hugo — verified count, then declared" do
      get patients_path

      positions = [ "Dani Medida", "Ana Autotriada", "Hugo Pocas Respuestas" ].map { |n| response.body.index(n) }
      expect(positions).to all(be_present)
      expect(positions).to eq(positions.sort)
    end

    # What the user hit on 2026-10-06: Ana is Candidato on her own answers and
    # her page said "Evaluación incompleta" with nothing met.
    it "explains Ana's Candidato on her patient page with what she declared" do
      ana = Patient.find_by!(participant_code: "PRUEBA-A")
      get patient_path(ana)

      body = CGI.unescapeHTML(response.body)
      expect(body).to include(I18n.t("criteria_assessments.self_report.basic", met: 5, total: 5))
      expect(body).to include(I18n.t("criteria_assessments.self_report.specific", met: 4, total: 7))
      expect(body).to include(I18n.t("criteria_assessments.recorded_heading"))
    end

    it "shows Ana's 9 answers beside the inputs, in words, and marks the 3 she was never asked" do
      ana = Patient.find_by!(participant_code: "PRUEBA-A")
      get patient_criteria_assessment_path(ana)

      body = CGI.unescapeHTML(response.body)
      declared = body.scan(%r{class="declared-value[^"]*">([^<]*)</span>}).flatten
      expect(declared.size).to eq(9)
      expect(declared).to include(I18n.t("common.yes"), I18n.t("common.no"), "40", "Intensa")
      expect(declared).not_to include("true", "false")
      expect(body.scan(I18n.t("criteria_assessments.capture.not_asked")).size).to eq(3)
    end

    it "takes a candidate to potential only once all 12 are recorded AND Aceptar is pressed" do
      ana = Patient.find_by!(participant_code: "PRUEBA-A")
      values = SelfReportScenario::CRITERIA.to_h { |row| [ rule(row[2]).id.to_s, row[8] ] }

      patch patient_criteria_assessment_path(ana), params: { values: values }
      expect(ana.reload.state).to eq("candidate")

      post transition_patient_path(ana), params: { event: "accept" }
      expect(ana.reload.state).to eq("potential")
    end

    it "sends a potential back to candidate when a specific value is recorded failing" do
      elena = Patient.find_by!(participant_code: "PRUEBA-E")
      ecg = rule("Alteración en el ECG de selección")

      patch patient_criteria_assessment_path(elena), params: { values: { ecg.id.to_s => "true" } }

      expect(elena.reload.state).to eq("candidate")
    end
  end
end
