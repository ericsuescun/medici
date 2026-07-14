class PatientsController < SecureApplicationController
  before_action :set_patient, only: %i[ show edit update destroy transition ]
  before_action -> { authorize(@patient, :update_state?) }, only: :transition

  # GET /patients or /patients.json
  def index
    @patients = Patient.all
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
    # Use callbacks to share common setup or constraints between actions.
    def set_patient
      @patient = Patient.find(params[:id])
    end

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
                                      :id_number)
    end
end
