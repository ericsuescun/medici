require 'rails_helper'

RSpec.describe "User activations (admin user manager)", type: :request do
  let(:sponsor) { FactoryBot.create(:sponsor, name: "Farma S.A.") }
  let(:other_sponsor) { FactoryBot.create(:sponsor, name: "Otra Farma") }
  let(:branch) { FactoryBot.create(:trial_center_branch, name: "Sede Norte") }

  let!(:sponsor_user) do
    FactoryBot.create(:user, :inactive, firstname: "Ana", lastname: "Ruiz",
                                        userable: FactoryBot.create(:sponsor_rep, sponsor: sponsor))
  end
  let!(:other_sponsor_user) do
    FactoryBot.create(:user, userable: FactoryBot.create(:sponsor_rep, sponsor: other_sponsor))
  end
  let!(:branch_user) do
    FactoryBot.create(:user, :inactive,
                      userable: FactoryBot.create(:trial_center_branch_rep, trial_center_branch: branch))
  end

  context "as a non-admin" do
    before { sign_in(FactoryBot.create(:user, :sponsor_rep), scope: :user) }

    it "is blocked from the activation manager" do
      get user_activations_path
      expect(response).to have_http_status(:redirect)
    end

    it "cannot activate an account" do
      patch user_activation_path(sponsor_user, active: true)
      expect(response).to have_http_status(:redirect)
      expect(sponsor_user.reload.active?).to be(false)
    end
  end

  context "as an admin" do
    let(:admin) { FactoryBot.create(:user, :admin) }

    before { sign_in(admin, scope: :user) }

    it "lists every account" do
      get user_activations_path
      expect(response).to be_successful
      expect(response.body).to include("Ana")
      expect(response.body).to include(branch_user.email)
    end

    it "filters by sponsor" do
      get user_activations_path(sponsor_id: sponsor.id)
      expect(response.body).to include(sponsor_user.email)
      expect(response.body).not_to include(other_sponsor_user.email)
      expect(response.body).not_to include(branch_user.email)
    end

    it "filters by trial centre branch" do
      get user_activations_path(trial_center_branch_id: branch.id)
      expect(response.body).to include(branch_user.email)
      expect(response.body).not_to include(sponsor_user.email)
    end

    it "filters by account kind" do
      get user_activations_path(type: "branch_reps")
      expect(response.body).to include(branch_user.email)
      expect(response.body).not_to include(sponsor_user.email)
    end

    it "filters by activation status" do
      get user_activations_path(status: "active")
      expect(response.body).to include(other_sponsor_user.email)
      expect(response.body).not_to include(sponsor_user.email)

      get user_activations_path(status: "inactive")
      expect(response.body).to include(sponsor_user.email)
      expect(response.body).not_to include(other_sponsor_user.email)
    end

    it "searches by name or email" do
      get user_activations_path(q: "ruiz")
      expect(response.body).to include(sponsor_user.email)
      expect(response.body).not_to include(branch_user.email)
    end

    it "activates an account" do
      patch user_activation_path(sponsor_user, active: true)

      expect(response).to redirect_to(user_activations_path)
      expect(sponsor_user.reload.active?).to be(true)
    end

    it "deactivates an account" do
      patch user_activation_path(other_sponsor_user, active: false)
      expect(other_sponsor_user.reload.active?).to be(false)
    end

    it "keeps the current filters after toggling" do
      patch user_activation_path(sponsor_user, active: true, sponsor_id: sponsor.id, status: "inactive")
      expect(response).to redirect_to(user_activations_path(sponsor_id: sponsor.id.to_s, status: "inactive"))
    end

    it "refuses to deactivate an admin account" do
      another_admin = FactoryBot.create(:user, :admin)

      patch user_activation_path(another_admin, active: false)

      expect(another_admin.reload.active?).to be(true)
      expect(flash[:alert]).to be_present
    end
  end
end
