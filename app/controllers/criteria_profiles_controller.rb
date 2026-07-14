class CriteriaProfilesController < SecureApplicationController
  before_action :set_criteria_profile, only: %i[ show edit update destroy ]

  # GET /criteria_profiles
  def index
    @criteria_profiles = CriteriaProfile.where(user: current_user).order(created_at: :desc).paginate(page: params[:page], per_page: RECORDS_PER_PAGE)
  end

  # GET /criteria_profiles/1
  def show
  end

  # GET /criteria_profiles/new
  def new
    @criteria_profile = CriteriaProfile.new
  end

  # GET /criteria_profiles/1/edit
  def edit
  end

  # POST /criteria_profiles
  def create
    @criteria_profile = CriteriaProfile.new(criteria_profile_params)
    @criteria_profile.user = current_user

    respond_to do |format|
      if @criteria_profile.save
        format.html { redirect_to criteria_profile_url(@criteria_profile), notice: t("criteria_profiles.flash.created") }
        format.json { render :show, status: :created, location: @criteria_profile }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @criteria_profile.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /criteria_profiles/1
  def update
    respond_to do |format|
      if @criteria_profile.update(criteria_profile_params)
        format.html { redirect_to criteria_profile_url(@criteria_profile), notice: t("criteria_profiles.flash.updated") }
        format.json { render :show, status: :ok, location: @criteria_profile }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @criteria_profile.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /criteria_profiles/1
  def destroy
    @criteria_profile.destroy!

    respond_to do |format|
      format.html { redirect_to criteria_profiles_url, notice: t("criteria_profiles.flash.destroyed") }
      format.json { head :no_content }
    end
  end

  private
    def set_criteria_profile
      # Ensure users can only access their own profiles
      @criteria_profile = CriteriaProfile.where(user: current_user).find(params[:id])
    end

    def criteria_profile_params
      params.require(:criteria_profile).permit(:name, :description, :study_id)
    end
end
