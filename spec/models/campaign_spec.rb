require 'rails_helper'

# == Schema Information
#
# Table name: campaigns
#
#  id                          :bigint           not null, primary key
#  call_to_action              :string
#  description                 :text
#  facebook_page_access_token  :text
#  instagram_access_token      :text
#  status                      :string           default("draft"), not null
#  target_facebook             :boolean          default(FALSE), not null
#  target_instagram            :boolean          default(FALSE), not null
#  target_twitter              :boolean          default(FALSE), not null
#  title                       :string           not null
#  twitter_access_token        :text
#  twitter_access_token_secret :text
#  twitter_api_key             :text
#  twitter_api_secret          :text
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  facebook_page_id            :text
#  instagram_user_id           :text
#  study_id                    :bigint           not null
#
# Indexes
#
#  index_campaigns_on_study_id  (study_id)
#
# Foreign Keys
#
#  fk_rails_...  (study_id => studies.id)
#
RSpec.describe Campaign, type: :model do
  it { is_expected.to belong_to(:study) }
  it { is_expected.to have_many(:campaign_documents).dependent(:destroy) }
  it { is_expected.to validate_presence_of(:title) }

  it "exposes the status enum values" do
    expect(Campaign.statuses.keys).to contain_exactly("draft", "ready", "archived")
  end

  describe "#targeted_platforms" do
    it "returns only the enabled channels" do
      campaign = build(:campaign, target_instagram: true, target_facebook: false, target_twitter: true)
      expect(campaign.targeted_platforms).to contain_exactly(:instagram, :twitter)
    end
  end

  describe "#publishing_configured?" do
    it "is false when no channel has an access token" do
      expect(build(:campaign).publishing_configured?).to be(false)
    end

    it "is true once any channel access token is present" do
      expect(build(:campaign, instagram_access_token: "tok").publishing_configured?).to be(true)
    end
  end

  describe "credential handling" do
    it "encrypts the access token at rest" do
      campaign = create(:campaign, instagram_access_token: "super-secret-token")
      raw = Campaign.connection.select_value(
        "SELECT instagram_access_token FROM campaigns WHERE id = #{campaign.id}"
      )
      expect(raw).not_to include("super-secret-token")
      expect(campaign.reload.instagram_access_token).to eq("super-secret-token")
    end

    it "keeps secret credentials out of the PaperTrail audit log" do
      campaign = create(:campaign, instagram_access_token: "audit-secret")
      serialized = campaign.versions.map { |v| [ v.object, v.object_changes ] }.to_s
      expect(serialized).not_to include("audit-secret")
    end
  end
end
