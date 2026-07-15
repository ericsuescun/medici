class CreateCampaigns < ActiveRecord::Migration[8.0]
  def change
    create_table :campaigns do |t|
      t.references :study, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :call_to_action
      t.string :status, null: false, default: "draft"

      # Which social channels this campaign is intended to promote on. Actual
      # publishing is gated behind Meta/X app review (see docs/social_publishing.md);
      # until then the module is a content library, and these are intent flags.
      t.boolean :target_instagram, null: false, default: false
      t.boolean :target_facebook, null: false, default: false
      t.boolean :target_twitter, null: false, default: false

      # Per-channel publishing credentials. Encrypted at the model layer
      # (ActiveRecord::Encryption). App-level secrets (Meta App ID/Secret, the X
      # OAuth client) live in ENV / Rails credentials, NOT here — see the doc.
      t.text :instagram_user_id
      t.text :instagram_access_token
      t.text :facebook_page_id
      t.text :facebook_page_access_token
      t.text :twitter_api_key
      t.text :twitter_api_secret
      t.text :twitter_access_token
      t.text :twitter_access_token_secret

      t.timestamps
    end
  end
end
