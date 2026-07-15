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
class Campaign < ApplicationRecord
  # Per-channel publishing secrets are encrypted; keep them out of the audit log
  # so plaintext credentials never land in the `versions` table.
  CREDENTIAL_FIELDS = %i[
    instagram_user_id instagram_access_token
    facebook_page_id facebook_page_access_token
    twitter_api_key twitter_api_secret
    twitter_access_token twitter_access_token_secret
  ].freeze

  # Secret credentials are rendered as blank password inputs; a blank submission
  # is ignored (see CampaignsController#campaign_params) so it never clobbers a
  # stored secret. The rest (public ids/keys) round-trip as plain text fields.
  SECRET_FIELDS = %i[
    instagram_access_token facebook_page_access_token
    twitter_api_secret twitter_access_token twitter_access_token_secret
  ].freeze

  has_paper_trail skip: CREDENTIAL_FIELDS

  belongs_to :study
  has_many :campaign_documents, dependent: :destroy

  CREDENTIAL_FIELDS.each { |field| encrypts field }

  # draft   => still being assembled
  # ready   => content finalized, ready to promote / publish
  # archived => kept for reference, no longer active
  enum :status, draft: "draft", ready: "ready", archived: "archived"

  validates :title, presence: true

  # The social channels this campaign is intended to promote on.
  def targeted_platforms
    platforms = []
    platforms << :instagram if target_instagram?
    platforms << :facebook if target_facebook?
    platforms << :twitter if target_twitter?
    platforms
  end

  # True once at least one channel's connection credentials are present. Actual
  # publishing is still gated behind Meta/X app review — see
  # docs/social_publishing.md. Until then the module is a content library.
  def publishing_configured?
    instagram_access_token.present? ||
      facebook_page_access_token.present? ||
      twitter_access_token.present?
  end
end
