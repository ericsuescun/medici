class CreateCampaignDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :campaign_documents do |t|
      t.references :campaign, null: false, foreign_key: true
      t.string :title
      # "file" => an uploaded asset (Active Storage); "external_link" => a URL
      # (e.g. a Google Docs / Drive link) stored in external_url.
      t.string :document_type, null: false, default: "file"
      t.string :external_url

      t.timestamps
    end
  end
end
