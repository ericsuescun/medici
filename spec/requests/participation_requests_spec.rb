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

  # A name is not clinical data, and since 2026-10-04 the form asks for one so a
  # rep has something to say after "buenos días". What stays out is the clinical
  # record: that is the rep's job after making contact, or step 2's.
  it "takes the name, and still nothing clinical" do
    post participation_requests_path(study_id: study.id),
         params: participation_params(authorized: true, firstname: "Ana", lastname: "Moreno",
                                      illness_description: "psoriasis", dob: "1990-01-01",
                                      sex: "female", notes: "nota")

    patient = Patient.last
    expect(patient.firstname).to eq("Ana")
    expect(patient.lastname).to eq("Moreno")
    expect(patient.illness_description).to be_blank
    expect(patient.dob).to be_nil
    expect(patient.sex).to be_blank
    expect(patient.notes).to be_blank
  end

  # The name is a convenience, never a condition — somebody who will leave a
  # phone number but not a name is still a lead worth calling.
  it "accepts a submission with no name at all" do
    expect {
      post participation_requests_path(study_id: study.id), params: participation_params(authorized: true)
    }.to change(Patient, :count).by(1)

    expect(Patient.last.display_name).to eq(Patient.last.participant_code)
  end

  # Provenance is recorded, not inferred from a blank name — that inference died
  # the moment this form could capture one.
  it "marks what it creates as self-registered, so the lead list still finds it" do
    post participation_requests_path(study_id: study.id),
         params: participation_params(authorized: true, firstname: "Ana")

    patient = Patient.last
    expect(patient).to be_self_registered
    expect(Patient.leads).to include(patient)
    expect(Patient.staff_entered).not_to include(patient)
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
