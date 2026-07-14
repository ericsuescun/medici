class TrialCenterFacilitiesController < SecureApplicationController
  before_action :set_trial_center_facility, only: %i[ show edit update destroy ]

  # GET /trial_center_facilities or /trial_center_facilities.json
  def index
    @trial_center_facilities = TrialCenterFacility.all.paginate(page: params[:page], per_page: RECORDS_PER_PAGE)
  end

  # GET /trial_center_facilities/1 or /trial_center_facilities/1.json
  def show
  end

  # GET /trial_center_facilities/new
  def new
    @trial_center_facility = TrialCenterFacility.new
    @cities = City.all.order(name: :asc).uniq
  end

  # GET /trial_center_facilities/1/edit
  def edit
    @cities = City.all.order(name: :asc).uniq
  end

  # POST /trial_center_facilities or /trial_center_facilities.json
  def create
    @trial_center_facility = TrialCenterFacility.new(trial_center_facility_params)

    respond_to do |format|
      if @trial_center_facility.save
        @trial_center_facility.cities << City.find(params[:trial_center_facility][:city_id])
        format.html { redirect_to trial_center_facility_url(@trial_center_facility), notice: t("trial_center_facilities.flash.created") }
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

        @trial_center_facility.cities.destroy_all
        @trial_center_facility.cities << City.find(params[:trial_center_facility][:city_id])

        format.html { redirect_to trial_center_facility_url(@trial_center_facility), notice: t("trial_center_facilities.flash.updated") }
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
      format.html { redirect_to trial_center_facilities_url, notice: t("trial_center_facilities.flash.destroyed") }
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
