class CitiesController < SecureApplicationController
  before_action :set_city, only: %i[ show edit update destroy ]

  # GET /cities or /cities.json
  def index
    @cities = City.order(:name)
    # Studies per city, narrowed to the signed-in user (a branch rep sees only
    # their branch's studies; admins and other permitted roles see all) — one
    # query for the whole table. The city↔study link goes through branches.
    pairs = Study.joins(:trial_center_branches)
                 .joins("INNER JOIN cities_trial_center_branches cctb ON cctb.trial_center_branch_id = trial_center_branches.id")
                 .where(trial_center_branches: { id: user_branch_scope.select(:id) })
                 .select("studies.*, cctb.city_id AS city_id")
                 .distinct
    @studies_by_city = pairs.group_by(&:city_id)
  end

  # GET /cities/1 or /cities/1.json
  def show
    # The user's branches located in this city, with the studies they run.
    @branches = user_branch_scope.joins(:cities).where(cities: { id: @city.id })
                                 .includes(:trial_center_facility, :studies)
                                 .distinct.order(:name)
  end

  # GET /cities/new
  def new
    @city = City.new
  end

  # GET /cities/1/edit
  def edit
  end

  # POST /cities or /cities.json
  def create
    @city = City.new(city_params)

    respond_to do |format|
      if @city.save
        format.html { redirect_to city_url(@city), notice: t("cities.created") }
        format.json { render :show, status: :created, location: @city }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @city.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /cities/1 or /cities/1.json
  def update
    respond_to do |format|
      if @city.update(city_params)
        format.html { redirect_to city_url(@city), notice: t("cities.updated") }
        format.json { render :show, status: :ok, location: @city }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @city.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /cities/1 or /cities/1.json
  def destroy
    @city.destroy!

    respond_to do |format|
      format.html { redirect_to cities_url, notice: t("cities.destroyed") }
      format.json { head :no_content }
    end
  end

  private
    # Same scoping rule as GlobalSearch: admin = every branch, a trial centre
    # rep = only their own branch, other permitted roles = all rows.
    def user_branch_scope
      return TrialCenterBranch.all if current_user.admin?

      if current_user.trial_center_branch_rep?
        branch = current_user.userable.trial_center_branch
        return branch ? TrialCenterBranch.where(id: branch.id) : TrialCenterBranch.none
      end

      TrialCenterBranch.all
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_city
      @city = City.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def city_params
      params.require(:city).permit(:name)
    end
end
