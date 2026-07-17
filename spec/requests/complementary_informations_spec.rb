require 'rails_helper'

RSpec.describe "Complementary information", type: :request do
  let(:patient) { FactoryBot.create(:patient) }

  def pdf_upload
    Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4 fake"), "application/pdf", original_filename: "exam.pdf")
  end

  def image_upload
    # 1x1 transparent PNG.
    png = [ "89504e470d0a1a0a0000000d4948445200000001000000010806000000" \
           "1f15c4890000000d49444154789c6360000002000100ffff030000060005" \
           "57bfabd40000000049454e44ae426082" ].pack("H*")
    Rack::Test::UploadedFile.new(StringIO.new(png), "image/png", original_filename: "scan.png")
  end

  describe "as an admin" do
    let(:admin_user) { FactoryBot.create(:user, :admin) }
    before { sign_in(admin_user, scope: :user) }

    it "shows the (empty) bundle without creating a row" do
      expect {
        get patient_complementary_information_path(patient)
      }.not_to change(ComplementaryInformation, :count)
      expect(response).to be_successful
    end

    it "saves notes and attaches a PDF and an image" do
      patch patient_complementary_information_path(patient), params: {
        complementary_information: { notes: "<div>Prior exams below.</div>", documents: [ pdf_upload ], images: [ image_upload ] }
      }

      expect(response).to redirect_to(patient_complementary_information_path(patient))
      info = patient.reload.complementary_information
      expect(info.notes.to_plain_text).to include("Prior exams")
      expect(info.documents.count).to eq(1)
      expect(info.images.count).to eq(1)
    end

    it "rejects a non-PDF uploaded as a document" do
      patch patient_complementary_information_path(patient), params: {
        complementary_information: { documents: [ image_upload ] }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(patient.reload.complementary_information&.documents&.attached?).to be_falsey
    end

    it "appends files across saves instead of replacing them" do
      patch patient_complementary_information_path(patient), params: { complementary_information: { documents: [ pdf_upload ] } }
      patch patient_complementary_information_path(patient), params: { complementary_information: { documents: [ pdf_upload ] } }
      expect(patient.reload.complementary_information.documents.count).to eq(2)
    end

    it "purges a single attachment" do
      patch patient_complementary_information_path(patient), params: { complementary_information: { documents: [ pdf_upload ] } }
      info = patient.reload.complementary_information
      att = info.documents.first

      delete purge_attachment_patient_complementary_information_path(patient, attachment_id: att.id)
      expect(response).to redirect_to(edit_patient_complementary_information_path(patient))
      expect(info.reload.documents.count).to eq(0)
    end

    it "renders the direct-upload file inputs on the edit form" do
      get edit_patient_complementary_information_path(patient)
      expect(response).to be_successful
      expect(response.body).to include("data-direct-upload-url")
    end
  end

  describe "row-level scoping for a trial centre rep" do
    let(:branch_a) { FactoryBot.create(:trial_center_branch) }
    let(:branch_b) { FactoryBot.create(:trial_center_branch) }
    let(:study_a) { FactoryBot.create(:study).tap { |s| s.trial_center_branches << branch_a } }
    let(:study_b) { FactoryBot.create(:study).tap { |s| s.trial_center_branches << branch_b } }
    let!(:mine) { FactoryBot.create(:patient, study: study_a) }
    let!(:theirs) { FactoryBot.create(:patient, study: study_b) }

    before do
      rep = FactoryBot.create(:user, userable: FactoryBot.create(:trial_center_branch_rep, trial_center_branch: branch_a))
      sign_in(rep, scope: :user)
    end

    it "reaches its own centre's patient" do
      get patient_complementary_information_path(mine)
      expect(response).to be_successful
    end

    it "404s on another centre's patient" do
      get patient_complementary_information_path(theirs)
      expect(response).to have_http_status(:not_found)
    end
  end
end
