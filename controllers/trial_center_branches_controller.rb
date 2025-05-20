class TrialCenterBranchesController < ApplicationController
  before_action :set_trial_center_branch, only: %i[ show edit update destroy ]

  # GET /trial_center_branches or /trial_center_branches.json
  def index
    @trial_center_branches = TrialCenterBranch.all
  end

  # GET /trial_center_branches/1 or /trial_center_branches/1.json
  def show
  end

  # GET /trial_center_branches/new
  def new
    @trial_center_branch = TrialCenterBranch.new
  end

  # GET /trial_center_branches/1/edit
  def edit
  end

  # POST /trial_center_branches or /trial_center_branches.json
  def create
    @trial_center_branch = TrialCenterBranch.new(trial_center_branch_params)

    respond_to do |format|
      if @trial_center_branch.save
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
        format.html { redirect_to trial_center_branch_url(@trial_center_branch), notice: "Trial center branch was successfully updated." }
        format.json { render :show, status: :ok, location: @trial_center_branch }
      else
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

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_trial_center_branch
      @trial_center_branch = TrialCenterBranch.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def trial_center_branch_params
      params.require(:trial_center_branch).permit(:name, :initials, :description, :trial_center_facility_id)
    end
end
