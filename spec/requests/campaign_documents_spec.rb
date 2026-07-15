require 'rails_helper'

RSpec.describe "CampaignDocuments", type: :request do
  let(:campaign) { create(:campaign) }
  let(:doc_attrs) do
    { title: "Brief", document_type: "external_link", external_url: "https://docs.google.com/document/d/xyz" }
  end

  it "lets platform_staff add a document (can_edit)" do
    sign_in create(:user, :platform_staff), scope: :user
    expect {
      post campaign_campaign_documents_path(campaign), params: { campaign_document: doc_attrs }
    }.to change(CampaignDocument, :count).by(1)
  end

  it "lets sponsor_rep add but not delete a document (edit yes, delete no)" do
    existing = create(:campaign_document, campaign: campaign)
    sign_in create(:user, :sponsor_rep), scope: :user

    expect {
      post campaign_campaign_documents_path(campaign), params: { campaign_document: doc_attrs }
    }.to change(CampaignDocument, :count).by(1)

    expect {
      delete campaign_document_path(existing)
    }.not_to change(CampaignDocument, :count)
  end

  it "forbids a patient from adding a document (view only)" do
    sign_in create(:user, :patient), scope: :user
    expect {
      post campaign_campaign_documents_path(campaign), params: { campaign_document: doc_attrs }
    }.not_to change(CampaignDocument, :count)
  end

  it "lets an admin delete a document" do
    doc = create(:campaign_document, campaign: campaign)
    sign_in create(:user, :admin), scope: :user
    expect {
      delete campaign_document_path(doc)
    }.to change(CampaignDocument, :count).by(-1)
  end
end
