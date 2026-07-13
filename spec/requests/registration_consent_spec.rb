require 'rails_helper'

# Ley 1581 de 2012 habeas-data authorization must be captured as a discrete,
# auditable step at registration, before any patient data is collected.
RSpec.describe "Patient registration consent (Ley 1581)", type: :request do
  let(:study) { FactoryBot.create(:study) }

  def signup_params(authorized:)
    {
      user: {
        email: "newpatient@example.com",
        password: "password123",
        password_confirmation: "password123",
        data_processing_authorization: authorized ? "1" : "0"
      }
    }
  end

  # GET new first so the study_id lands in the session (how the real flow works).
  before { get new_user_registration_path(study_id: study.id) }

  it "creates the account + patient + an auditable Consent when authorization is granted" do
    expect {
      post user_registration_path, params: signup_params(authorized: true)
    }.to change(User, :count).by(1)
      .and change(Consent, :count).by(1)

    user = User.last
    expect(user.patient?).to be(true)

    consent = Consent.last
    expect(consent.user).to eq(user)
    expect(consent.document_type).to eq(Consent::LEY_1581_HABEAS_DATA)
    expect(consent.document_version).to eq(Consent::LEY_1581_CURRENT_VERSION)
    expect(consent.purpose).to eq(Consent::PURPOSE_SENSITIVE_HEALTH)
    expect(consent.granted_at).to be_present
  end

  it "blocks registration entirely when authorization is not granted" do
    expect {
      post user_registration_path, params: signup_params(authorized: false)
    }.to change(User, :count).by(0)

    expect(Consent.count).to eq(0)
    expect(Patient.count).to eq(0)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Debe autorizar")
  end
end
