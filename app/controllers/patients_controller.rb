class PatientsController < SecureApplicationController
  before_action :set_patient, only: %i[ show edit update destroy transition ]
  before_action -> { authorize(@patient, :update_state?) }, only: :transition

  # GET /patients or /patients.json
  #
  # Grouped by study. `policy_scope` is what keeps a trial centre rep to the
  # patients of their own centre — see PatientPolicy::Scope.
  # Review order within each study: candidates first (they asked for the rep's
  # attention — many arrive auto-triaged from their own questionnaire answers),
  # then interested, then participants; ties broken by how much of the
  # questionnaire they filled in, fullest first.
  STATE_REVIEW_ORDER = { "candidate" => 0, "interested" => 1, "participant" => 2 }.freeze

  def index
    # The criteria profile and answers are eager-loaded because every row asks
    # `policy(patient).assess?`, which runs Patient's AASM guards, which evaluate
    # the patient against their study's rules. Without this it is an N+1.
    # patient_declarations feeds both the triage guard and the fill count.
    patients = policy_scope(Patient)
               .includes(:variable_values, :patient_declarations, study: { criteria_profile: :criteria_variables })
               .to_a

    @declaration_counts = patients.to_h do |p|
      [ p.id, p.patient_declarations.count { |d| d.superseded_at.nil? } ]
    end

    @patients_by_study = patients
                         .sort_by { |p| [ STATE_REVIEW_ORDER.fetch(p.state, 9), -@declaration_counts[p.id] ] }
                         .group_by(&:study)
  end

  # GET /patients/1 or /patients/1.json
  #
  # The patient page is BOTH the demographic record and the clinical briefing —
  # they were two pages until 2026-08-24 and a rep had to bounce between them to
  # answer one question ("who is this and can they move forward?"). Demographics
  # read on the left, the eligibility picture on the right.
  def show
    @profile = @patient.study&.criteria_profile
    # Memoized on the patient, so the AASM guards consulted by `policy(@patient)`
    # further down the page reuse this evaluation instead of redoing it per call.
    @result = @patient.eligibility_result
    @complementary_information = @patient.complementary_information
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

  # Moving a patient through the trial lifecycle. This IS the rep's recorded
  # decision — PaperTrail versions the state change with the acting user, so who
  # promoted whom, and when, is auditable.
  #
  # Forward steps (assess/accept) additionally require the study's PRIMARY
  # criteria to be satisfied — each at its own evidence tier: assess (triage)
  # accepts self-reported declarations, accept (clinical) requires
  # investigator-recorded values. The rule is enforced on the model as AASM
  # guards, which `policy(@patient).assess?` already reflects via `may_assess?`;
  # it is re-checked here PER TIER purely so a blocked rep is told *why*
  # instead of getting a bare "not authorized". Checking the wrong tier here
  # would wrongly refuse a rep assessing a self-report-qualified patient.
  TRANSITION_EVENTS = %w[assess accept discard reject].freeze

  def transition
    event = params[:event].to_s

    return refuse_transition(t("errors.not_authorized")) unless TRANSITION_EVENTS.include?(event)

    tier_check = Patient::FORWARD_EVENT_CHECKS[event]
    if tier_check && !@patient.public_send(tier_check)
      return refuse_transition(t("patients.primary_criteria_required"))
    end

    return refuse_transition(t("errors.not_authorized")) unless policy(@patient).public_send("#{event}?")

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
    # Bounce a refused state change back where it came from, saying why.
    def refuse_transition(reason)
      redirect_back fallback_location: patient_url(@patient), alert: reason
    end

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
