# A patient's complementary information (prior exams as PDFs/images + notes).
# Like SOAP notes, access is gated by the parent patient's visibility rather
# than the Role permission matrix: reps reach only their own centre's patients.
class ComplementaryInformationsController < SecureApplicationController
  before_action :set_patient
  before_action :set_information
  before_action :authorize_read!, only: :show
  before_action :authorize_write!, only: %i[edit update purge_attachment]

  def show
  end

  def edit
  end

  def update
    @information.patient = @patient
    @information.notes = information_params[:notes] if information_params.key?(:notes)
    attach_new(:documents)
    attach_new(:images)

    if @information.save
      redirect_to patient_complementary_information_path(@patient), notice: t("complementary_informations.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Remove a single attached file. Scoped to this patient's bundle so a crafted
  # id cannot purge another record's attachment.
  def purge_attachment
    attachment = ActiveStorage::Attachment.find_by(id: params[:attachment_id], record: @information)
    attachment&.purge_later
    redirect_to edit_patient_complementary_information_path(@patient), notice: t("complementary_informations.file_removed")
  end

  private

  def set_patient
    @patient = policy_scope(Patient).find(params[:patient_id])
  end

  # One bundle per patient; build (unsaved) if none exists yet so `show`/`edit`
  # always have an object to render.
  def set_information
    @information = @patient.complementary_information || @patient.build_complementary_information
  end

  def authorize_read!
    authorize(@patient, :show?)
  end

  def authorize_write!
    authorize(@patient, :update?)
  end

  # Gated by the parent patient, not the permission matrix (see SoapNotesController).
  def authorization_model
    nil
  end

  # Append newly uploaded files without replacing the existing collection.
  def attach_new(field)
    Array(params.dig(:complementary_information, field)).each do |file|
      next if file.blank?

      @information.public_send(field).attach(file)
    end
  end

  def information_params
    params.fetch(:complementary_information, {}).permit(:notes)
  end
end
