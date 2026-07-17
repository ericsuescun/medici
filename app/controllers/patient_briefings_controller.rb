# A one-page treatment briefing for reps and admins: the patient's lifecycle
# state, eligibility verdict (what's passing / pending / out of reach), recent
# SOAP notes, and complementary information — everything a clinician needs to
# decide the next step, in one place. Read-only; actions (promote, assess,
# add notes) link out to the existing flows.
#
# Access is gated by the parent patient's visibility, like SoapNotesController.
class PatientBriefingsController < SecureApplicationController
  before_action :set_patient
  before_action -> { authorize(@patient, :show?) }

  def show
    @profile = @patient.study&.criteria_profile
    @result = @profile&.evaluate(@patient)
    @recent_notes = @patient.soap_notes.recent.limit(5)
    @notes_count = @patient.soap_notes.count
    @complementary_information = @patient.complementary_information
  end

  private

  def set_patient
    @patient = policy_scope(Patient).find(params[:patient_id])
  end

  # Gated by the parent patient, not the permission matrix (see SoapNotesController).
  def authorization_model
    nil
  end
end
