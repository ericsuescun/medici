class PatientsController < SecureApplicationController
  before_action :set_patient, only: %i[ show edit update destroy transition ]
  before_action -> { authorize(@patient, :update_state?) }, only: :transition

  # GET /patients — THE RECRUITMENT PIPELINE.
  #
  # Only the states that are still work: `interested` and `candidate`. Enrolled
  # patients moved to #potentials below, because they are a result to report
  # rather than a queue to work, and mixing them meant the page a rep opens all
  # day grew by one permanently-irrelevant row per success.
  #
  # `policy_scope` is what keeps a trial centre rep to their own centre and a
  # sponsor rep to their own sponsor — see PatientPolicy::Scope. PatientFilter
  # only ever narrows that further, so no query string can widen it.
  def index
    @filter = build_filter(policy_scope(Patient).recruiting, Patient::RECRUITING_STATES)
    @patients_by_study = grouped_patients(@filter.results)
  end

  # GET /patients/potentials — the ones cleared on both tiers, read as results.
  #
  # A custom collection action, so ResourceAuthorization does not cover it and
  # the authorize call has to be explicit (its after_action would flag a miss).
  def potentials
    authorize(Patient, :index?)

    @filter = build_filter(policy_scope(Patient).potentials, [ Patient::FINAL_STATE ])
    @patients_by_study = grouped_patients(@filter.results)
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

    # Re-checked here only to say WHY, per tier: the AASM guard already refuses
    # it, but "not authorized" would not tell a rep which criteria are missing.
    tier_check = Patient::FORWARD_EVENT_CHECKS[event]
    if tier_check && !@patient.public_send(tier_check)
      return refuse_transition(t("patients.#{event}_criteria_required"))
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

  # Recommendations a rep can filter by. Unlike everything in PatientFilter this
  # one cannot be a WHERE: it comes from EligibilityResult, which evaluates a
  # patient against their study's rules in Ruby. It is applied after loading —
  # affordable only because this page already evaluates every row anyway (each
  # one asks `policy(patient).assess?`, which runs the AASM guards).
  RECOMMENDATIONS = %w[ready promising blocked pending].freeze

  private
    def build_filter(base, allowed_states)
      PatientFilter.new(base, params.permit(*PatientFilter::PERMITTED).to_h, allowed_states: allowed_states)
    end

    def recommendation_filter
      value = params[:recommendation].to_s
      value if RECOMMENDATIONS.include?(value)
    end

    # Loads the filtered relation and groups it for the page.
    #
    # The eager loads are not optional: every row asks `policy(patient).assess?`,
    # which runs Patient's AASM guards, which evaluate the patient against their
    # study's criteria profile. Without them this is an N+1 per row.
    # patient_declarations feeds both the triage guard and the fill count.
    def grouped_patients(relation)
      patients = relation
                 .includes(:variable_values, :patient_declarations, study: { criteria_profile: :criteria_variables })
                 .in_review_order
                 .to_a

      @declaration_counts = patients.to_h do |patient|
        [ patient.id, patient.patient_declarations.count { |d| d.superseded_at.nil? } ]
      end

      # index.json.jbuilder renders @patients, so it has to keep existing: the
      # rewrite that introduced @patients_by_study left the JSON view rendering
      # a nil collection, which Jbuilder turns into `[]` rather than an error —
      # a consumer told there are no patients instead of told it is broken.
      @patients = patients

      @recommendation = recommendation_filter
      if @recommendation
        patients.select! { |patient| patient.eligibility_result&.recommendation.to_s == @recommendation }
      end

      # State first, then how close the record is to clearing the next gate
      # (see #review_rank), then how much of the questionnaire they filled in
      # (fullest first — they gave the rep the most to go on). `sort_by` is not
      # stable, so the original index rides along as the last key: without it,
      # ties would scramble the newest-first order the SQL already established.
      patients
        .each_with_index
        .sort_by { |patient, i| [ *review_rank(patient), -@declaration_counts[patient.id], i ] }
        .map(&:first)
        .group_by(&:study)
    end

    # How near this patient is to the step they are waiting on — the ordering
    # the rep works down. A candidate is waiting on the SPECIFIC tier, so the
    # count of specific criteria met ranks them, most-complete first.
    #
    # VERIFIED outranks DECLARED, and they are separate keys rather than a sum:
    # an investigator's measurement and a patient's answer are not the same
    # evidence, and a queue that added them would quietly promote the patient
    # who answered confidently over the one somebody actually measured. Declared
    # breaks ties beneath it — which is what makes answering the questionnaire
    # worth the patient's time, since it moves them up a rep's list without ever
    # moving them through a gate. The basic score ranks the interested ones
    # behind both. Negated because sort_by is ascending.
    def review_rank(patient)
      verified = patient.eligibility_result
      declared = patient.self_report_result

      [ Patient::STATE_REVIEW_ORDER.fetch(patient.state, 9),
        -(verified&.specific_score || 0),
        -(declared&.specific_score || 0),
        -(verified&.basic_score || 0) ]
    end

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
