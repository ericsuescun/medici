# == Schema Information
#
# Table name: campaign_documents
#
#  id            :bigint           not null, primary key
#  document_type :string           default("file"), not null
#  external_url  :string
#  title         :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  campaign_id   :bigint           not null
#
# Indexes
#
#  index_campaign_documents_on_campaign_id  (campaign_id)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id)
#
FactoryBot.define do
  factory :campaign_document do
    association :campaign, factory: :campaign
    title { "Study flyer" }

    # Default: an external link (e.g. a Google Docs URL).
    document_type { "external_link" }
    external_url { "https://docs.google.com/document/d/abc123" }

    trait :with_file do
      document_type { "file" }
      external_url { nil }
      after(:build) do |doc|
        doc.file.attach(
          io: StringIO.new("%PDF-1.4 fake pdf bytes"),
          filename: "flyer.pdf",
          content_type: "application/pdf"
        )
      end
    end
  end
end
