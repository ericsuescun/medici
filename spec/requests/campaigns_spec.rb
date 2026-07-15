require 'rails_helper'

# Exercises the Role-permission matrix for the Campaign module end-to-end:
# platform_staff (full), sponsor_rep (view+edit, no delete), patient (view only),
# admin (full), and anonymous (blocked).
RSpec.describe "Campaigns", type: :request do
  let(:study) { create(:study) }
  let(:campaign) { create(:campaign, study: study) }
  let(:valid_attrs) { { title: "Awareness", description: "d", call_to_action: "Join", status: "draft" } }

  context "as platform_staff (full access)" do
    before { sign_in create(:user, :platform_staff), scope: :user }

    it "lists campaigns for a study" do
      campaign
      get study_campaigns_path(study)
      expect(response).to be_successful
    end

    it "creates a campaign" do
      expect {
        post study_campaigns_path(study), params: { campaign: valid_attrs }
      }.to change(Campaign, :count).by(1)
    end

    it "updates a campaign" do
      patch campaign_path(campaign), params: { campaign: { title: "Renamed" } }
      expect(campaign.reload.title).to eq("Renamed")
    end

    it "deletes a campaign" do
      campaign
      expect { delete campaign_path(campaign) }.to change(Campaign, :count).by(-1)
    end
  end

  context "as sponsor_rep (view + edit, no delete)" do
    before { sign_in create(:user, :sponsor_rep), scope: :user }

    it "can view a campaign" do
      get campaign_path(campaign)
      expect(response).to be_successful
    end

    it "can update a campaign" do
      patch campaign_path(campaign), params: { campaign: { title: "Edited" } }
      expect(campaign.reload.title).to eq("Edited")
    end

    it "cannot delete a campaign" do
      campaign
      expect { delete campaign_path(campaign) }.not_to change(Campaign, :count)
      expect(response).to have_http_status(:redirect)
    end
  end

  context "as patient (view only)" do
    before { sign_in create(:user, :patient), scope: :user }

    it "can view a campaign" do
      get campaign_path(campaign)
      expect(response).to be_successful
    end

    it "cannot create a campaign" do
      expect {
        post study_campaigns_path(study), params: { campaign: valid_attrs }
      }.not_to change(Campaign, :count)
    end

    it "cannot update a campaign" do
      patch campaign_path(campaign), params: { campaign: { title: "Nope" } }
      expect(campaign.reload.title).not_to eq("Nope")
    end
  end

  context "as admin (full access)" do
    before { sign_in create(:user, :admin), scope: :user }

    it "deletes a campaign" do
      campaign
      expect { delete campaign_path(campaign) }.to change(Campaign, :count).by(-1)
    end
  end

  context "publishing credential handling on update (platform_staff)" do
    before { sign_in create(:user, :platform_staff), scope: :user }

    it "preserves a stored secret when the secret field is submitted blank" do
      campaign.update!(instagram_access_token: "stored-token")
      patch campaign_path(campaign), params: { campaign: { title: "Retitled", instagram_access_token: "" } }
      campaign.reload
      expect(campaign.title).to eq("Retitled")
      expect(campaign.instagram_access_token).to eq("stored-token")
    end

    it "updates the secret when a non-blank value is submitted" do
      campaign.update!(instagram_access_token: "old-token")
      patch campaign_path(campaign), params: { campaign: { instagram_access_token: "new-token" } }
      expect(campaign.reload.instagram_access_token).to eq("new-token")
    end
  end

  context "when not signed in" do
    it "does not allow listing campaigns" do
      get study_campaigns_path(study)
      expect(response).to have_http_status(:redirect)
    end
  end
end
