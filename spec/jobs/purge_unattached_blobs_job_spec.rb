require 'rails_helper'

RSpec.describe PurgeUnattachedBlobsJob do
  def create_blob(filename: "exam.png")
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake image bytes"),
      filename: filename,
      content_type: "image/png"
    )
  end

  def backdate(blob)
    blob.update_column(:created_at, (described_class::TTL + 1.day).ago)
  end

  it "purges blobs that have been unattached longer than the TTL" do
    blob = create_blob
    backdate(blob)

    expect(described_class.perform_now).to eq(1)
    expect(ActiveStorage::Blob.exists?(blob.id)).to be(false)
  end

  it "leaves fresh unattached blobs alone (an open form may still submit them)" do
    blob = create_blob

    expect(described_class.perform_now).to eq(0)
    expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)
  end

  it "never touches attached blobs, however old" do
    info = FactoryBot.create(:complementary_information)
    info.images.attach(create_blob)
    blob = info.images.first.blob
    backdate(blob)

    expect(described_class.perform_now).to eq(0)
    expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)
  end

  it "keeps images embedded in rich text, then purges them once the section is cleared" do
    blob = create_blob
    note = FactoryBot.create(
      :complementary_information,
      notes: ActionText::Content.new("Con imagen").append_attachables(blob).to_html
    )
    backdate(blob)

    # Embedded via the RichText embeds attachment — the sweep must keep it.
    expect(described_class.perform_now).to eq(0)
    expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)

    # Assigning "" destroys the RichText row (store_if_blank: false), which
    # detaches the embed; the sweep may now reclaim the blob. (A browser
    # clear submits "<div><br></div>" instead — same outcome via the embed
    # re-sync. In test the enqueued purge_later never runs, exactly like a
    # lost job in prod.)
    note.update!(notes: "")
    expect(note.reload.notes.body).to be_blank

    expect(described_class.perform_now).to eq(1)
    expect(ActiveStorage::Blob.exists?(blob.id)).to be(false)
  end

  it "also frees the embed when the section is cleared the way a browser does" do
    blob = create_blob
    note = FactoryBot.create(
      :complementary_information,
      notes: ActionText::Content.new("Con imagen").append_attachables(blob).to_html
    )
    backdate(blob)

    # Trix serializes a visually-empty editor as "<div><br></div>", which is
    # `present?` — the RichText row survives (store_if_blank never fires) and
    # the before_save embed re-sync must detach the image instead.
    note.update!(notes: "<div><br></div>")

    expect(described_class.perform_now).to eq(1)
    expect(ActiveStorage::Blob.exists?(blob.id)).to be(false)
  end
end
