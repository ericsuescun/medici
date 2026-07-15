require 'rails_helper'

# Server-rendered UI, so rack_test (no JS) is enough. Default locale is :es, so
# assertions use the Spanish strings the pages render.
RSpec.feature "Campaign module", type: :feature do
  let(:study) { create(:study) }

  scenario "platform staff creates a campaign and attaches a document link" do
    login_as create(:user, :platform_staff), scope: :user

    visit study_campaigns_path(study)
    click_link I18n.t("campaigns.new")

    fill_in Campaign.human_attribute_name(:title), with: "Awareness Week"
    fill_in Campaign.human_attribute_name(:description), with: "Reach more patients"
    check Campaign.human_attribute_name(:target_instagram)
    click_button I18n.t("common.save")

    expect(page).to have_content("Awareness Week")
    expect(page).to have_content(I18n.t("campaigns.platform.instagram"))

    # Add an external-link document (e.g. a Google Docs URL).
    fill_in CampaignDocument.human_attribute_name(:title), with: "Creative brief"
    select I18n.t("enums.campaign_document.document_type.external_link"),
           from: CampaignDocument.human_attribute_name(:document_type)
    fill_in CampaignDocument.human_attribute_name(:external_url), with: "https://docs.google.com/document/d/xyz"
    click_button I18n.t("campaign_documents.add")

    expect(page).to have_link("Creative brief")
  end

  scenario "platform staff uploads a file document" do
    campaign = create(:campaign, study: study)
    login_as create(:user, :platform_staff), scope: :user

    visit campaign_path(campaign)
    fill_in CampaignDocument.human_attribute_name(:title), with: "Study flyer"
    select I18n.t("enums.campaign_document.document_type.file"),
           from: CampaignDocument.human_attribute_name(:document_type)
    attach_file CampaignDocument.human_attribute_name(:file),
                Rails.root.join("spec/fixtures/files/flyer.pdf")
    click_button I18n.t("campaign_documents.add")

    expect(page).to have_link("Study flyer")
    expect(campaign.campaign_documents.last.file).to be_attached
  end

  scenario "staff reach the global campaigns table from the navbar" do
    campaign = create(:campaign, study: study)
    login_as create(:user, :platform_staff), scope: :user

    visit root_path
    click_link I18n.t("nav.campaigns")

    expect(page).to have_content(I18n.t("campaigns.all_title"))
    expect(page).to have_content(campaign.title)
    expect(page).to have_content(campaign.study.public_title)
    expect(page).to have_content(I18n.t("enums.campaign.status.#{campaign.status}"))
  end

  scenario "a patient sees campaigns read-only (no management controls)" do
    campaign = create(:campaign, study: study)
    login_as create(:user, :patient), scope: :user

    visit study_campaigns_path(study)
    expect(page).to have_content(I18n.t("campaigns.index_title"))
    expect(page).to have_no_link(I18n.t("campaigns.new"))

    visit campaign_path(campaign)
    expect(page).to have_no_link(I18n.t("common.edit"))
    expect(page).to have_no_button(I18n.t("common.destroy"))
    expect(page).to have_no_button(I18n.t("campaign_documents.add"))
  end
end
