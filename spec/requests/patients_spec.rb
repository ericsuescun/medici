require 'rails_helper'

RSpec.describe "Patients", type: :request do
  let(:patient) { FactoryBot.create(:patient) }

  describe "POST /patients/:id/transition" do
    context "as an admin (authorized)" do
      before { sign_in(FactoryBot.create(:user, :admin), scope: :user) }

      it "assess transitions interested -> candidate" do
        post transition_patient_path(patient), params: { event: "assess" }

        expect(response).to have_http_status(:redirect)
        expect(patient.reload.state).to eq("candidate")
      end

      # The rep pressing the button IS the recorded decision — that is the whole
      # audit story for promotions, so it gets an assertion rather than trust.
      it "records the acting user against the state change in the audit trail" do
        admin = FactoryBot.create(:user, :admin)
        sign_in(admin, scope: :user)

        post transition_patient_path(patient), params: { event: "assess" }

        version = patient.reload.versions.last
        expect(version.event).to eq("update")
        expect(version.whodunnit).to eq(admin.id.to_s)
        expect(version.changeset["state"]).to eq([ "interested", "candidate" ])
      end

      it "rejects an invalid event without changing state" do
        post transition_patient_path(patient), params: { event: "bogus" }

        expect(response).to have_http_status(:redirect)
        expect(patient.reload.state).to eq("interested")
      end
    end

    # Server-side enforcement, not just a disabled button: a hand-crafted POST
    # must be refused too. The rule lives on the model as an AASM guard.
    context "when the study's primary criteria are not met" do
      let(:study) { FactoryBot.create(:study) }
      let(:profile) { FactoryBot.create(:criteria_profile, study: study) }
      let(:patient) { FactoryBot.create(:patient, study: study) }
      let!(:age) do
        profile.criteria_variables.create!(
          name: "Edad", variable_type: "inclusion", value_type: "quantitative",
          comparison_type: "between_range", reference_value_1: 18, reference_value_2: 40
        )
      end

      before { sign_in(FactoryBot.create(:user, :admin), scope: :user) }

      def record_age(value)
        patient.variable_values.create!(
          criteria_variable: age, name: "Edad", value: value.to_s,
          value_type: "quantitative", comparison_type: "between_range",
          criteria_category: "primary", reference_value_1: 18, reference_value_2: 40
        )
      end

      it "refuses the transition while the criterion is unrecorded, and says why" do
        post transition_patient_path(patient), params: { event: "assess" }

        expect(patient.reload.state).to eq("interested")
        expect(flash[:alert]).to eq(I18n.t("patients.primary_criteria_required"))
      end

      it "refuses the transition when the recorded value fails the criterion" do
        record_age(50)

        post transition_patient_path(patient), params: { event: "assess" }

        expect(patient.reload.state).to eq("interested")
        expect(flash[:alert]).to eq(I18n.t("patients.primary_criteria_required"))
      end

      it "allows the transition once the criterion is recorded and met" do
        record_age(30)

        post transition_patient_path(patient), params: { event: "assess" }

        expect(patient.reload.state).to eq("candidate")
        expect(flash[:notice]).to eq(I18n.t("patients.state_updated"))
      end

      # The controller's friendly re-check must use the TRIAGE tier for assess:
      # a patient qualified only by their own declarations is assessable, and
      # checking the clinical tier here would wrongly refuse the rep.
      it "lets a rep assess a patient qualified by self-reported declarations alone" do
        patient.patient_declarations.create!(
          criteria_variable: age, prompt: "¿Edad?", answer: "30",
          value_type: "quantitative", capture_mode: "interview", declared_at: Time.current
        )

        post transition_patient_path(patient), params: { event: "assess" }

        expect(patient.reload.state).to eq("candidate")
        expect(flash[:notice]).to eq(I18n.t("patients.state_updated"))
      end

      it "still requires investigator values for accept, whatever was declared" do
        patient.patient_declarations.create!(
          criteria_variable: age, prompt: "¿Edad?", answer: "30",
          value_type: "quantitative", capture_mode: "interview", declared_at: Time.current
        )
        post transition_patient_path(patient), params: { event: "assess" }
        expect(patient.reload.state).to eq("candidate")

        post transition_patient_path(patient), params: { event: "accept" }

        expect(patient.reload.state).to eq("candidate")
        expect(flash[:alert]).to eq(I18n.t("patients.primary_criteria_required"))
      end

      it "still allows walking a patient back when the criteria no longer hold" do
        value = record_age(30)
        post transition_patient_path(patient), params: { event: "assess" }
        expect(patient.reload.state).to eq("candidate")

        value.update!(value: "50") # criteria broken out from under the candidate

        post transition_patient_path(patient), params: { event: "discard" }
        expect(patient.reload.state).to eq("interested")
      end
    end

    context "as a user whose role cannot see patients (unauthorized)" do
      before { sign_in(FactoryBot.create(:user, :sponsor_rep), scope: :user) }

      # 404, not a redirect: patients are now loaded through `policy_scope`, so a
      # user with no patient access cannot find the record at all. That is
      # deliberate — a 403 would confirm the patient exists, which is itself a
      # disclosure about an identifiable person.
      it "is refused and leaves the state unchanged" do
        post transition_patient_path(patient), params: { event: "assess" }

        expect(response).to have_http_status(:not_found)
        expect(patient.reload.state).to eq("interested")
      end
    end
  end
end
