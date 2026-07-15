class PatientsController < SecureApplicationController
  before_action :set_patient, only: %i[ show edit update destroy transition ]
  before_action -> { authorize(@patient, :update_state?) }, only: :transition

  # GET /patients or /patients.json
  #
  # Grouped by study. `policy_scope` is what keeps a trial centre rep to the
  # patients of their own centre — see PatientPolicy::Scope.
  def index
    @patients_by_study = policy_scope(Patient)
                         .includes(:study)
                         .order(:state)
                         .group_by(&:study)
  end

  # GET /patients/1 or /patients/1.json
  def show
  end

  # GET /patients/new
  def new
    @patient = Patient.new
  end

  # GET /patients/1/edit
  def edit
  end

  # POST /patients or /patients.json
  def create
    @patient = Patient.new(patient_params)

    # A rep may only enrol into a study that runs at their own centre. The form
    # only offers those, but the check has to live here too — the select is not
    # a security boundary.
    unless policy(Patient).enrol_into?(@patient.study)
      @patient.errors.add(:study_id, t("patients.study_not_enrollable"))
      render :new, status: :unprocessable_entity and return
    end

    respond_to do |format|
      if @patient.save
        format.html { redirect_to patient_url(@patient), notice: t("patients.created") }
        format.json { render :show, status: :created, location: @patient }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @patient.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /patients/1 or /patients/1.json
  def update
    respond_to do |format|
      if @patient.update(patient_params)
        format.html { redirect_to patient_url(@patient), notice: t("patients.updated") }
        format.json { render :show, status: :ok, location: @patient }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @patient.errors, status: :unprocessable_entity }
      end
    end
  end

  def transition
    event = params[:event].to_s

    # Map events to policy checks
    allowed = case event
    when "assess" then policy(@patient).assess?
    when "accept" then policy(@patient).accept?
    when "discard" then policy(@patient).discard?
    when "reject" then policy(@patient).reject?
    else false
    end

    if !allowed
      redirect_back fallback_location: patient_url(@patient), alert: t("errors.not_authorized") and return
    end

    begin
      @patient.public_send("#{event}!")
      redirect_back fallback_location: patient_url(@patient), notice: t("patients.state_updated")
    rescue StandardError => e
      redirect_back fallback_location: patient_url(@patient), alert: t("patients.state_update_failed", message: e.message)
    end
  end

  # DELETE /patients/1 or /patients/1.json
  def destroy
    @patient.destroy!

    respond_to do |format|
      format.html { redirect_to patients_url, notice: t("patients.destroyed") }
      format.json { head :no_content }
    end
  end

  private
    # Loading through `policy_scope` is the row-level access control: a trial
    # centre rep reaching for a patient outside their centre gets a 404 instead
    # of the record. 404 rather than 403 on purpose — a 403 would confirm that
    # the patient exists, which is itself a disclosure about an identifiable
    # person. This also covers the custom `transition` action for free.
    def set_patient
      @patient = policy_scope(Patient).find(params[:id])
    end

    # Studies this user may enrol a patient into: their own centre's for a rep,
    # all of them for an admin. Used for the form's select AND re-checked on
    # write, so a hand-crafted POST cannot smuggle in another centre's study.
    def enrollable_studies
      @enrollable_studies ||=
        if current_user.admin?
          Study.order(:public_title)
        else
          branch = current_user.userable&.trial_center_branch
          branch ? branch.studies.order(:public_title) : Study.none
        end
    end
    helper_method :enrollable_studies

    # Only allow a list of trusted parameters through.
    # NOTE: :state is intentionally NOT permitted here — patient state changes
    # go exclusively through the policy-guarded #transition action, never mass-assignment.
    def patient_params
      params.require(:patient).permit(:firstname,
                                      :lastname,
                                      :dob,
                                      :sex,
                                      :contact_number,
                                      :contact_address,
                                      :email,
                                      :notes,
                                      :country,
                                      :illness_description,
                                      :id_type,
                                      :id_number,
                                      :study_id)
    end
end
