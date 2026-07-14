class SponsorRepsController < SecureApplicationController
  before_action :set_sponsor_rep, only: %i[ show edit update destroy ]

  def index
    @sponsor_reps = SponsorRep.includes(:user).paginate(page: params[:page], per_page: RECORDS_PER_PAGE)
  end

  def show
  end

  def new
    @sponsor_rep = SponsorRep.new
    @sponsor_rep.sponsor_id = params[:sponsor_id] if params[:sponsor_id].present?
    @sponsor_rep.build_user
  end

  def edit
    @sponsor_rep.build_user unless @sponsor_rep.user
  end

  def create
    @sponsor_rep = SponsorRep.new(sponsor_rep_params)

    respond_to do |format|
      if @sponsor_rep.save
        format.html { redirect_to sponsor_rep_url(@sponsor_rep), notice: t("sponsor_reps.created") }
        format.json { render :show, status: :created, location: @sponsor_rep }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @sponsor_rep.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @sponsor_rep.update(sponsor_rep_params)
        format.html { redirect_to sponsor_rep_url(@sponsor_rep), notice: t("sponsor_reps.updated") }
        format.json { render :show, status: :ok, location: @sponsor_rep }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @sponsor_rep.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @sponsor_rep.destroy!

    respond_to do |format|
      format.html { redirect_to sponsor_reps_url, notice: t("sponsor_reps.destroyed") }
      format.json { head :no_content }
    end
  end

  private
    def set_sponsor_rep
      @sponsor_rep = SponsorRep.find(params[:id])
    end

    def sponsor_rep_params
      params.require(:sponsor_rep).permit(:contact_number, :contact_address, :title, :sponsor_id,
                                          user_attributes: [ :id, :firstname, :lastname, :email, :password, :password_confirmation ])
    end
end
