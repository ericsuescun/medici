require 'rails_helper'

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
RSpec.describe CampaignDocument, type: :model do
  it { is_expected.to belong_to(:campaign) }

  it "is valid as an external link with a url" do
    expect(build(:campaign_document)).to be_valid
  end

  it "requires a url when it is an external link" do
    doc = build(:campaign_document, external_url: nil)
    expect(doc).not_to be_valid
    expect(doc.errors[:external_url]).to be_present
  end

  it "is valid with an attached, allowed file" do
    expect(build(:campaign_document, :with_file)).to be_valid
  end

  it "requires a file when the document type is file" do
    doc = build(:campaign_document, document_type: "file", external_url: nil)
    expect(doc).not_to be_valid
    expect(doc.errors[:file]).to be_present
  end

  it "rejects a disallowed upload content type" do
    doc = build(:campaign_document, document_type: "file", external_url: nil)
    doc.file.attach(io: StringIO.new("MZ"), filename: "malware.exe", content_type: "application/x-msdownload")
    expect(doc).not_to be_valid
    expect(doc.errors[:file]).to be_present
  end

  it "rejects an unknown document type" do
    expect(build(:campaign_document, document_type: "bogus")).not_to be_valid
  end

  it "rejects a disallowed file even on an external_link document" do
    doc = build(:campaign_document, document_type: "external_link", external_url: "https://x.test")
    doc.file.attach(io: StringIO.new("MZ"), filename: "x.exe", content_type: "application/x-msdownload")
    expect(doc).not_to be_valid
    expect(doc.errors[:file]).to be_present
  end

  describe "#display_name" do
    it "falls back to the external url when there is no title" do
      doc = build(:campaign_document, title: nil, external_url: "https://x.test/doc")
      expect(doc.display_name).to eq("https://x.test/doc")
    end
  end
end
