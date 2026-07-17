require 'rails_helper'

RSpec.describe "SOAP notes", type: :request do
  let(:patient) { FactoryBot.create(:patient) }

  describe "as an admin" do
    let(:admin_user) { FactoryBot.create(:user, :admin) }
    before { sign_in(admin_user, scope: :user) }

    it "lists a patient's notes" do
      FactoryBot.create(:soap_note, patient: patient, subjective: "Reported dizziness.")
      get patient_soap_notes_path(patient)
      expect(response).to be_successful
      expect(response.body).to include("Reported dizziness.")
    end

    it "creates a note, attributes the author, and stores rich text" do
      expect {
        post patient_soap_notes_path(patient), params: {
          soap_note: { encounter_date: Date.current, subjective: "<div>Headache x2 weeks.</div>", plan: "<div>Hydration.</div>" }
        }
      }.to change { patient.soap_notes.count }.by(1)

      note = patient.soap_notes.last
      expect(note.author).to eq(admin_user)
      expect(note.subjective.to_plain_text).to include("Headache")
      expect(note.plan.to_plain_text).to include("Hydration")
    end

    it "rejects a note with every section blank" do
      expect {
        post patient_soap_notes_path(patient), params: { soap_note: { encounter_date: Date.current } }
      }.not_to change { patient.soap_notes.count }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "renders the rich-text editor on the new form" do
      get new_patient_soap_note_path(patient)
      expect(response).to be_successful
      expect(response.body).to include("trix-editor")
    end
  end

  describe "as a sponsor rep (may not see or edit patient data)" do
    before { sign_in(FactoryBot.create(:user, :sponsor_rep), scope: :user) }

    it "cannot create a note" do
      post patient_soap_notes_path(patient), params: { soap_note: { encounter_date: Date.current, subjective: "x" } }
      # Sponsor reps have no Patient permission, so the patient is out of their
      # policy_scope and the request 404s rather than confirming it exists.
      expect(response).not_to have_http_status(:success)
      expect(patient.soap_notes.count).to eq(0)
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

    it "reaches its own centre's patient notes" do
      get patient_soap_notes_path(mine)
      expect(response).to be_successful
    end

    it "404s on another centre's patient (no disclosure that they exist)" do
      get patient_soap_notes_path(theirs)
      expect(response).to have_http_status(:not_found)
    end
  end
end
