require 'rails_helper'

# Proves the generic Role-permission enforcement wired through
# ResourceAuthorization + ApplicationPolicy against the default matrix.
RSpec.describe "Role-based authorization", type: :request do
  let(:medication) { FactoryBot.create(:medication) }

  context "as a patient (Medication: show-only in the default matrix)" do
    before { sign_in(FactoryBot.create(:user, :patient), scope: :user) }

    it "can view the medications index" do
      get medications_path
      expect(response).to be_successful
    end

    it "is blocked from editing a medication" do
      get edit_medication_path(medication)
      expect(response).to have_http_status(:redirect)
    end

    it "is blocked from deleting a medication (record survives)" do
      delete medication_path(medication)
      expect(response).to have_http_status(:redirect)
      expect(Medication.exists?(medication.id)).to be(true)
    end
  end

  context "as a sponsor_rep (no Patient access in the default matrix)" do
    before { sign_in(FactoryBot.create(:user, :sponsor_rep), scope: :user) }

    it "is blocked from the patients index" do
      get patients_path
      expect(response).to have_http_status(:redirect)
    end
  end

  context "as an admin (full access)" do
    before { sign_in(FactoryBot.create(:user, :admin), scope: :user) }

    it "can reach a medication edit page" do
      get edit_medication_path(medication)
      expect(response).to be_successful
    end

    it "can delete a medication" do
      medication # create it before measuring the count change
      expect { delete medication_path(medication) }.to change(Medication, :count).by(-1)
    end
  end
end
