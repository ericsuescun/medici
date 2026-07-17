# SOAP notes are clinical documentation *about* a patient, written and read by
# the research team. Access is therefore gated by the parent patient's
# visibility — exactly like CriteriaAssessmentsController — rather than by the
# Role permission matrix: a trial centre rep reaches only the patients of their
# own centre (via policy_scope), and only admins/reps may edit patient data.
class SoapNotesController < SecureApplicationController
  before_action :set_patient
  before_action :set_soap_note, only: %i[show edit update destroy]
  before_action :authorize_read!, only: %i[index show]
  before_action :authorize_write!, only: %i[new create edit update destroy]

  def index
    @soap_notes = @patient.soap_notes.recent
  end

  def show
  end

  def new
    @soap_note = @patient.soap_notes.build(encounter_date: Date.current)
  end

  def edit
  end

  def create
    @soap_note = @patient.soap_notes.build(soap_note_params)
    @soap_note.author = current_user

    if @soap_note.save
      redirect_to patient_soap_note_path(@patient, @soap_note), notice: t("soap_notes.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @soap_note.update(soap_note_params)
      redirect_to patient_soap_note_path(@patient, @soap_note), notice: t("soap_notes.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @soap_note.destroy!
    redirect_to patient_soap_notes_path(@patient), notice: t("soap_notes.destroyed")
  end

  private

  # policy_scope is the row-level gate: an out-of-reach patient 404s (never a 403
  # that would confirm the patient exists — see PatientsController).
  def set_patient
    @patient = policy_scope(Patient).find(params[:patient_id])
  end

  def set_soap_note
    @soap_note = @patient.soap_notes.find(params[:id])
  end

  def authorize_read!
    authorize(@patient, :show?)
  end

  def authorize_write!
    authorize(@patient, :update?)
  end

  # Authorization is delegated to the parent patient (above), so opt out of the
  # generic class-level authorization that would otherwise look SoapNote up in
  # the permission matrix (where it deliberately does not appear) and deny all.
  def authorization_model
    nil
  end

  def soap_note_params
    params.require(:soap_note).permit(:encounter_date, :subjective, :objective, :assessment, :plan)
  end
end
