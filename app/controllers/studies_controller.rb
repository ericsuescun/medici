class StudiesController < SecureApplicationController
  before_action :set_study, only: %i[ show edit update destroy ]

  # GET /studies or /studies.json
  def index
    @studies = Study.all
  end

  # GET /studies/1 or /studies/1.json
  def show
  end

  # GET /studies/new
  def new
    @study = Study.new
  end

  # GET /studies/1/edit
  def edit
  end

  # POST /studies or /studies.json
  def create
    @study = Study.new(study_params)

    respond_to do |format|
      if @study.save
        format.html { redirect_to study_url(@study), notice: "Study was successfully created." }
        format.json { render :show, status: :created, location: @study }
      else
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

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_study
      @study = Study.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def study_params
      params.require(:study).permit(:sponsor_id, :study_status, :local_unique_register, :scientific_title, :public_title, :registered_at, :approved_at, :started_at, :first_patient_at, :global_ending_at, :study_type, :study_phase, :inclusion_criteria, :exclusion_criteria, :sample_size, :main_intervention, :control_group, :participant_starting_age, :participant_ending_age, :sex, :medical_preexistences, :ethical_committee, :ethical_approval_at, :keywords, :pathology, :medication, :reviewed, :review_user_id)
    end
end
