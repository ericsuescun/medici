class StudiesController < SecureApplicationController
  before_action :set_study, only: %i[ show edit update destroy add_trial_center_branch remove_trial_center_branch add_medication remove_medication set_criteria_profile unset_criteria_profile ]
  before_action :set_commercial_data
  before_action -> { authorize(@study, :update?) },
                only: %i[add_trial_center_branch remove_trial_center_branch add_medication
                         remove_medication set_criteria_profile unset_criteria_profile]

  # GET /studies or /studies.json
  def index
    @studies = Study.all.paginate(page: params[:page], per_page: RECORDS_PER_PAGE)
    @recruitment = RecruitmentProgress.for(@studies)
  end

  # GET /studies/1 or /studies/1.json
  def show
    # The old @study.users.patients read the dead studies_users join (always
    # empty since patients stopped being Users). The patient LIST is row-level
    # data about identifiable people, so it goes through PatientPolicy::Scope:
    # admins see all of the study's patients, a branch rep only their reach,
    # roles without Patient access (sponsor reps) an empty list — while the
    # aggregate counter in the view stays a plain count.
    @patients = policy_scope(Patient).where(study: @study)
  end

  # GET /studies/new?study_type=observational|interventional
  #
  # There is no generic "new study" entry point any more: the type decides which
  # approval the form asks about, so it is chosen up front (see the index's
  # dropdown) and travels as a hidden field. An unknown/missing type falls back
  # to interventional rather than rendering a form with no approval question.
  def new
    @study = Study.new(study_type: requested_study_type)
  end

  # GET /studies/1/edit
  def edit
    # @sponsors = Sponsor.all
    # @trial_center_branches = TrialCenterBranch.all
  end

  # POST /studies or /studies.json
  def create
    @study = Study.new(study_params)
    trial_center_branch = TrialCenterBranch.find(params[:study][:trial_center_branch_id])

    respond_to do |format|
      if @study.save
        trial_center_branch.studies << @study

        format.html { redirect_to study_url(@study), notice: t("studies.created") }
        format.json { render :show, status: :created, location: @study }
      else
        # @trial_center_branches = TrialCenterBranch.all
        # @sponsors = Sponsor.all
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @study.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /studies/1 or /studies/1.json
  def update
    respond_to do |format|
      if @study.update(study_params)
        format.html { redirect_to study_url(@study), notice: t("studies.updated") }
        format.json { render :show, status: :ok, location: @study }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @study.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /studies/1 or /studies/1.json
  def destroy
    @study.destroy!

    respond_to do |format|
      format.html { redirect_to studies_url, notice: t("studies.destroyed") }
      format.json { head :no_content }
    end
  end

  # POST /studies/1/add_trial_center_branch
  def add_trial_center_branch
    trial_center_branch = TrialCenterBranch.find(params[:trial_center_branch_id])

    unless @study.trial_center_branches.include?(trial_center_branch)
      @study.trial_center_branches << trial_center_branch
      notice = t("studies.branch_added")
    else
      notice = t("studies.branch_already_associated")
    end

    redirect_to study_url(@study), notice: notice
  end

  # DELETE /studies/1/remove_trial_center_branch
  def remove_trial_center_branch
    trial_center_branch = TrialCenterBranch.find(params[:trial_center_branch_id])

    if @study.trial_center_branches.count > 1
      @study.trial_center_branches.delete(trial_center_branch)
      notice = t("studies.branch_removed")
    else
      notice = t("studies.branch_cannot_remove_last")
    end

    redirect_to study_url(@study), notice: notice
  end

  # POST /studies/1/add_medication
  def add_medication
    medication = Medication.find(params[:medication_id])

    if @study.medications.include?(medication)
      notice = t("studies.medication_already_associated")
    elsif @study.medications.count >= 3
      notice = t("studies.medication_max_reached")
    else
      @study.medications << medication
      notice = t("studies.medication_added")
    end

    redirect_to study_url(@study), notice: notice
  end

  # DELETE /studies/1/remove_medication
  def remove_medication
    medication = Medication.find(params[:medication_id])

    if @study.medications.count > 1
      @study.medications.delete(medication)
      notice = t("studies.medication_removed")
    else
      notice = t("studies.medication_cannot_remove_last")
    end

    redirect_to study_url(@study), notice: notice
  end

  # POST /studies/1/set_criteria_profile
  def set_criteria_profile
    profile = CriteriaProfile.find(params[:criteria_profile_id])

    # Clear any existing profile associated to this study
    CriteriaProfile.where(study_id: @study.id).update_all(study_id: nil)

    # Associate the selected one
    profile.update!(study: @study)

    redirect_to study_url(@study), notice: t("studies.profile_associated")
  end

  # DELETE /studies/1/unset_criteria_profile
  def unset_criteria_profile
    profile = CriteriaProfile.find_by(study_id: @study.id)
    if profile
      profile.update!(study_id: nil)
      notice = t("studies.profile_unset")
    else
      notice = t("studies.profile_none_associated")
    end
    redirect_to study_url(@study), notice: notice
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_study
      @study = Study.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def study_params
      params.require(:study).permit(:city_id, :sponsor_id, :study_status, :study_type, :scientific_title, :public_title, :short_title, :completed_at, :started_at, :first_patient_at, :global_ending_at, :study_phase, :inclusion_criteria, :exclusion_criteria, :sample_size, :main_intervention, :sex, :reviewed, :review_user_id, :local_health_authority_approved, :committee_approved, category_ids: [])
    end

    def requested_study_type
      Study.study_types.key?(params[:study_type]) ? params[:study_type] : "interventional"
    end

  def set_commercial_data
    @sponsors = Sponsor.all
    @trial_center_branches = TrialCenterBranch.all
  end
end
