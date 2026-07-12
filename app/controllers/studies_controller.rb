class StudiesController < SecureApplicationController
  before_action :set_study, only: %i[ show edit update destroy add_trial_center_branch remove_trial_center_branch add_medication remove_medication set_criteria_profile unset_criteria_profile ]
  before_action :set_commercial_data
  before_action -> { authorize(@study, :update?) },
                only: %i[add_trial_center_branch remove_trial_center_branch add_medication
                         remove_medication set_criteria_profile unset_criteria_profile]

  # GET /studies or /studies.json
  def index
    @studies = Study.all.paginate(page: params[:page], per_page: RECORDS_PER_PAGE)
  end

  # GET /studies/1 or /studies/1.json
  def show
    @patients = @study.users.patients
  end

  # GET /studies/new
  def new
    @study = Study.new
    # @sponsors = Sponsor.all
    # @trial_center_branches = TrialCenterBranch.all
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

        format.html { redirect_to study_url(@study), notice: "Study was successfully created." }
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
        format.html { redirect_to study_url(@study), notice: "Study was successfully updated." }
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
      format.html { redirect_to studies_url, notice: "Study was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  # POST /studies/1/add_trial_center_branch
  def add_trial_center_branch
    trial_center_branch = TrialCenterBranch.find(params[:trial_center_branch_id])

    unless @study.trial_center_branches.include?(trial_center_branch)
      @study.trial_center_branches << trial_center_branch
      notice = "Trial center branch was successfully added."
    else
      notice = "Trial center branch was already associated with this study."
    end

    redirect_to study_url(@study), notice: notice
  end

  # DELETE /studies/1/remove_trial_center_branch
  def remove_trial_center_branch
    trial_center_branch = TrialCenterBranch.find(params[:trial_center_branch_id])

    if @study.trial_center_branches.count > 1
      @study.trial_center_branches.delete(trial_center_branch)
      notice = "Trial center branch was successfully removed."
    else
      notice = "Cannot remove the last trial center branch from this study."
    end

    redirect_to study_url(@study), notice: notice
  end

  # POST /studies/1/add_medication
  def add_medication
    medication = Medication.find(params[:medication_id])

    if @study.medications.include?(medication)
      notice = "Medication was already associated with this study."
    elsif @study.medications.count >= 3
      notice = "A study can have a maximum of 3 medications."
    else
      @study.medications << medication
      notice = "Medication was successfully added."
    end

    redirect_to study_url(@study), notice: notice
  end

  # DELETE /studies/1/remove_medication
  def remove_medication
    medication = Medication.find(params[:medication_id])

    if @study.medications.count > 1
      @study.medications.delete(medication)
      notice = "Medication was successfully removed."
    else
      notice = "Cannot remove the last medication from this study."
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

    redirect_to study_url(@study), notice: "Perfil de criterios asociado exitosamente."
  end

  # DELETE /studies/1/unset_criteria_profile
  def unset_criteria_profile
    profile = CriteriaProfile.find_by(study_id: @study.id)
    if profile
      profile.update!(study_id: nil)
      notice = "Perfil de criterios desasociado."
    else
      notice = "Este estudio no tiene un perfil de criterios asociado."
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
      params.require(:study).permit(:city_id, :sponsor_id, :study_status, :scientific_title, :public_title, :short_title, :completed_at, :started_at, :first_patient_at, :global_ending_at, :study_phase, :inclusion_criteria, :exclusion_criteria, :sample_size, :main_intervention, :sex, :reviewed, :review_user_id)
    end

  def set_commercial_data
    @sponsors = Sponsor.all
    @trial_center_branches = TrialCenterBranch.all
  end
end
