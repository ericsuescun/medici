class TrialCenterBranchRepsController < SecureApplicationController
  before_action :set_trial_center_branch_rep, only: %i[ show edit update destroy ]

  def index
    @trial_center_branch_reps = TrialCenterBranchRep.includes(:user).paginate(page: params[:page], per_page: RECORDS_PER_PAGE)
  end

  def show
  end

  def new
    @trial_center_branch_rep = TrialCenterBranchRep.new
    @trial_center_branch_rep.trial_center_branch_id = params[:trial_center_branch_id] if params[:trial_center_branch_id].present?
    @trial_center_branch_rep.build_user
  end

  def edit
    @trial_center_branch_rep.build_user unless @trial_center_branch_rep.user
  end

  def create
    @trial_center_branch_rep = TrialCenterBranchRep.new(trial_center_branch_rep_params)

    respond_to do |format|
      if @trial_center_branch_rep.save
        format.html { redirect_to trial_center_branch_rep_url(@trial_center_branch_rep), notice: "Trial center branch representative was successfully created." }
        format.json { render :show, status: :created, location: @trial_center_branch_rep }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @trial_center_branch_rep.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @trial_center_branch_rep.update(trial_center_branch_rep_params)
        format.html { redirect_to trial_center_branch_rep_url(@trial_center_branch_rep), notice: "Trial center branch representative was successfully updated." }
        format.json { render :show, status: :ok, location: @trial_center_branch_rep }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @trial_center_branch_rep.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @trial_center_branch_rep.destroy!

    respond_to do |format|
      format.html { redirect_to trial_center_branch_reps_url, notice: "Trial center branch representative was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    def set_trial_center_branch_rep
      @trial_center_branch_rep = TrialCenterBranchRep.find(params[:id])
    end

    def trial_center_branch_rep_params
      params.require(:trial_center_branch_rep).permit(:contact_number, :contact_address, :title, :trial_center_branch_id,
                                          user_attributes: [ :id, :firstname, :lastname, :email, :password, :password_confirmation ])
    end
end
