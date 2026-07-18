require 'rails_helper'

# The engine endpoint every direct upload (Trix images, complementary-info
# files) posts to before any form submit. It ships unauthenticated; the
# initializer gates it because all upload surfaces are staff-only.
RSpec.describe "Active Storage direct uploads", type: :request do
  let(:blob_params) do
    {
      blob: {
        filename: "exam.pdf",
        byte_size: 12,
        checksum: Digest::MD5.base64digest("fake content"),
        content_type: "application/pdf"
      }
    }
  end

  it "rejects anonymous blob creation" do
    expect {
      post rails_direct_uploads_path, params: blob_params, as: :json
    }.not_to change(ActiveStorage::Blob, :count)

    expect(response).to have_http_status(:unauthorized)
  end

  it "still lets signed-in staff direct-upload" do
    sign_in(FactoryBot.create(:user, :admin), scope: :user)

    expect {
      post rails_direct_uploads_path, params: blob_params, as: :json
    }.to change(ActiveStorage::Blob, :count).by(1)

    expect(response).to be_successful
    expect(response.parsed_body).to include("signed_id")
  end
end
