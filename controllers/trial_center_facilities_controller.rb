class TrialCenterFacilitiesController < SecureApplicationController
  before_action :set_trial_center_facility, only: %i[ show edit update destroy ]

  # GET /trial_center_facilities or /trial_center_facilities.json
  def index
    @trial_center_facilities = TrialCenterFacility.all
  end

  # GET /trial_center_facilities/1 or /trial_center_facilities/1.json
  def show
  end

  # GET /trial_center_facilities/new
  def new
    @trial_center_facility = TrialCenterFacility.new
  end

  # GET /trial_center_facilities/1/edit
  def edit
  end

  # POST /trial_center_facilities or /trial_center_facilities.json
  def create
    @trial_center_facility = TrialCenterFacility.new(trial_center_facility_params)

    respond_to do |format|
      if @trial_center_facility.save
        format.html { redirect_to trial_center_facility_url(@trial_center_facility), notice: "Trial center facility was successfully created." }
        format.json { render :show, status: :created, location: @trial_center_facility }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @trial_center_facility.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /trial_center_facilities/1 or /trial_center_facilities/1.json
  def update
    respond_to do |format|
      if @trial_center_facility.update(trial_center_facility_params)
        format.html { redirect_to trial_center_facility_url(@trial_center_facility), notice: "Trial center facility was successfully updated." }
        format.json { render :show, status: :ok, location: @trial_center_facility }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @trial_center_facility.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /trial_center_facilities/1 or /trial_center_facilities/1.json
  def destroy
    @trial_center_facility.destroy!

    respond_to do |format|
      format.html { redirect_to trial_center_facilities_url, notice: "Trial center facility was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_trial_center_facility
      @trial_center_facility = TrialCenterFacility.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def trial_center_facility_params
      params.require(:trial_center_facility).permit(:name, :initials, :email, :description, :contact_number, :contact_address, :url)
    end
end
