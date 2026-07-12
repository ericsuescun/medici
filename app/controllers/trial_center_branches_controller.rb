class TrialCenterBranchesController < SecureApplicationController
  before_action :set_trial_center_branch, only: %i[ show edit update destroy add_rep remove_rep ]
  before_action -> { authorize(@trial_center_branch, :update?) }, only: %i[add_rep remove_rep]

  # GET /trial_center_branches or /trial_center_branches.json
  def index
    @trial_center_branches = TrialCenterBranch.all.paginate(page: params[:page], per_page: RECORDS_PER_PAGE)
  end

  # GET /trial_center_branches/1 or /trial_center_branches/1.json
  def show
  end

  # GET /trial_center_branches/new
  def new
    @trial_center_branch = TrialCenterBranch.new
    @cities = City.all.order(name: :asc).uniq
  end

  # GET /trial_center_branches/1/edit
  def edit
    @cities = City.all.order(name: :asc).uniq
  end

  # POST /trial_center_branches or /trial_center_branches.json
  def create
    @trial_center_branch = TrialCenterBranch.new(trial_center_branch_params)

    respond_to do |format|
      if @trial_center_branch.save
        @trial_center_branch.cities << City.find(params[:trial_center_branch][:city_id])

        @cities = City.all.order(name: :asc).uniq

        format.html { redirect_to trial_center_branch_url(@trial_center_branch), notice: "Trial center branch was successfully created." }
        format.json { render :show, status: :created, location: @trial_center_branch }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @trial_center_branch.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /trial_center_branches/1 or /trial_center_branches/1.json
  def update
    respond_to do |format|
      if @trial_center_branch.update(trial_center_branch_params)
        # Update city association if city_id is provided
        if params[:trial_center_branch][:city_id].present?
          # Clear existing cities and add the new one
          @trial_center_branch.cities.clear
          @trial_center_branch.cities << City.find(params[:trial_center_branch][:city_id])
        end

        format.html { redirect_to trial_center_branch_url(@trial_center_branch), notice: "Trial center branch was successfully updated." }
        format.json { render :show, status: :ok, location: @trial_center_branch }
      else
        @cities = City.all.order(name: :asc).uniq
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @trial_center_branch.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /trial_center_branches/1 or /trial_center_branches/1.json
  def destroy
    @trial_center_branch.destroy!

    respond_to do |format|
      format.html { redirect_to trial_center_branches_url, notice: "Trial center branch was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  # POST /trial_center_branches/:id/add_rep
  def add_rep
    rep = TrialCenterBranchRep.find(params[:rep_id])
    rep.update!(trial_center_branch: @trial_center_branch)
    redirect_to trial_center_branch_path(@trial_center_branch), notice: "Representante de sede asociado correctamente."
  end

  # DELETE /trial_center_branches/:id/remove_rep
  def remove_rep
    rep = TrialCenterBranchRep.find(params[:rep_id])
    rep.update!(trial_center_branch: nil)
    redirect_to trial_center_branch_path(@trial_center_branch), notice: "Representante de sede desasociado."
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_trial_center_branch
      @trial_center_branch = TrialCenterBranch.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def trial_center_branch_params
      params.require(:trial_center_branch).permit(:name, :initials, :description, :email, :contact_number, :contact_address, :url, :trial_center_facility_id)
    end
end
