require 'rails_helper'

RSpec.describe "Patients", type: :request do
  let(:patient) { FactoryBot.create(:patient) }

  describe "POST /patients/:id/transition" do
    context "as an admin (authorized)" do
      before { sign_in(FactoryBot.create(:user, :admin), scope: :user) }

      it "assess transitions prospect -> candidate" do
        post transition_patient_path(patient), params: { event: "assess" }

        expect(response).to have_http_status(:redirect)
        expect(patient.reload.state).to eq("candidate")
      end

      it "rejects an invalid event without changing state" do
        post transition_patient_path(patient), params: { event: "bogus" }

        expect(response).to have_http_status(:redirect)
        expect(patient.reload.state).to eq("prospect")
      end
    end

    context "as a patient (unauthorized)" do
      before { sign_in(FactoryBot.create(:user, :patient), scope: :user) }

      it "is refused and leaves the state unchanged" do
        post transition_patient_path(patient), params: { event: "assess" }

        expect(response).to have_http_status(:redirect)
        expect(patient.reload.state).to eq("prospect")
      end
    end
  end
end
