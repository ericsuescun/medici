class TrialCitiesController < ApplicationController
  before_action :set_trial_city, only: %i[ show edit update destroy ]

  # GET /trial_cities or /trial_cities.json
  def index
    @trial_cities = TrialCity.all
  end

  # GET /trial_cities/1 or /trial_cities/1.json
  def show
  end

  # GET /trial_cities/new
  def new
    @trial_city = TrialCity.new
  end

  # GET /trial_cities/1/edit
  def edit
  end

  # POST /trial_cities or /trial_cities.json
  def create
    @trial_city = TrialCity.new(trial_city_params)

    respond_to do |format|
      if @trial_city.save
        format.html { redirect_to trial_city_url(@trial_city), notice: "Trial city was successfully created." }
        format.json { render :show, status: :created, location: @trial_city }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @trial_city.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /trial_cities/1 or /trial_cities/1.json
  def update
    respond_to do |format|
      if @trial_city.update(trial_city_params)
        format.html { redirect_to trial_city_url(@trial_city), notice: "Trial city was successfully updated." }
        format.json { render :show, status: :ok, location: @trial_city }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @trial_city.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /trial_cities/1 or /trial_cities/1.json
  def destroy
    @trial_city.destroy!

    respond_to do |format|
      format.html { redirect_to trial_cities_url, notice: "Trial city was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_trial_city
      @trial_city = TrialCity.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def trial_city_params
      params.require(:trial_city).permit(:studies_id, :name)
    end
end
