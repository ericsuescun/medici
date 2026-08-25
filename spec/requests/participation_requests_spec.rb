require 'rails_helper'

# The public "¡Quiero participar!" flow. It creates NO account — just a Patient
# record for a trial centre rep to call back.
#
# Leaving a phone number against a named clinical trial says something about your
# health, so the Ley 1581 de 2012 habeas-data authorization is still a hard gate:
# nothing is written until it is granted. These examples are the guard on that.
RSpec.describe "Participation requests", type: :request do
  let(:study) { FactoryBot.create(:study) }

  # adult_confirmed rides along by default: it is a second hard gate (Ley 1581
  # Art. 7 — minors' data), and these examples are about the habeas-data one.
  def participation_params(authorized:, **overrides)
    {
      patient: {
        contact_number: "300 123 4567",
        data_processing_authorization: authorized ? "1" : "0",
        adult_confirmed: "1"
      }.merge(overrides)
    }
  end

  it "is reachable without an account" do
    get new_participation_request_path(study_id: study.id)

    expect(response).to be_successful
    expect(response.body).to include(study.public_title)
  end

  it "creates a patient + an auditable Consent, and no account, when authorized" do
    expect {
      post participation_requests_path(study_id: study.id), params: participation_params(authorized: true)
    }.to change(Patient, :count).by(1)
      .and change(Consent, :count).by(1)
      .and change(User, :count).by(0)

    patient = Patient.last
    expect(patient.study).to eq(study)
    expect(patient.contact_number).to eq("300 123 4567")
    expect(patient.state).to eq("interested")
    expect(patient.user).to be_nil

    consent = Consent.last
    expect(consent.patient).to eq(patient)
    expect(consent.document_type).to eq(Consent::LEY_1581_HABEAS_DATA)
    expect(consent.document_version).to eq(Consent::LEY_1581_CURRENT_VERSION)
    expect(consent.purpose).to eq(Consent::PURPOSE_SENSITIVE_HEALTH)
    expect(consent.granted_at).to be_present
  end

  it "collects nothing clinical — that is the rep's job after making contact" do
    post participation_requests_path(study_id: study.id),
         params: participation_params(authorized: true, illness_description: "psoriasis", firstname: "Ana")

    patient = Patient.last
    expect(patient.illness_description).to be_blank
    expect(patient.firstname).to be_blank
  end

  describe "the habeas-data gate" do
    it "writes absolutely nothing when authorization is withheld" do
      expect {
        post participation_requests_path(study_id: study.id), params: participation_params(authorized: false)
      }.to change(Patient, :count).by(0)
        .and change(Consent, :count).by(0)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "contact details" do
    it "accepts a phone alone" do
      expect {
        post participation_requests_path(study_id: study.id),
             params: participation_params(authorized: true, email: "")
      }.to change(Patient, :count).by(1)
    end

    it "accepts an email alone" do
      expect {
        post participation_requests_path(study_id: study.id),
             params: participation_params(authorized: true, contact_number: "", email: "ana@example.com")
      }.to change(Patient, :count).by(1)
    end

    it "accepts both" do
      expect {
        post participation_requests_path(study_id: study.id),
             params: participation_params(authorized: true, email: "ana@example.com")
      }.to change(Patient, :count).by(1)
    end

    # Neither field is mandatory on its own, but a lead nobody can call back is
    # useless — the entire point is that a rep contacts them.
    it "rejects a request with neither" do
      expect {
        post participation_requests_path(study_id: study.id),
             params: participation_params(authorized: true, contact_number: "", email: "")
      }.to change(Patient, :count).by(0)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  context "when the study's sponsor is international" do
    let(:study) { FactoryBot.create(:study, sponsor: FactoryBot.create(:sponsor, :international)) }

    it "also records a distinct cross-border-transfer consent (Ley 1581 Art. 26)" do
      post participation_requests_path(study_id: study.id), params: participation_params(authorized: true)

      expect(Patient.last.consents.pluck(:document_type)).to contain_exactly(
        Consent::LEY_1581_HABEAS_DATA,
        Consent::LEY_1581_CROSS_BORDER
      )
    end
  end

  it "does NOT record a cross-border consent for a domestic sponsor" do
    post participation_requests_path(study_id: study.id), params: participation_params(authorized: true)

    expect(Patient.last.consents.pluck(:document_type)).to eq([ Consent::LEY_1581_HABEAS_DATA ])
  end
end
