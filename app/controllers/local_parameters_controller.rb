# Admin-only manager for country-specific configuration (see LocalParameter).
# Standard actions are authorized generically by ResourceAuthorization ->
# LocalParameterPolicy, which is admin-only.
class LocalParametersController < SecureApplicationController
  before_action :set_local_parameter, only: %i[ show edit update destroy ]
  before_action :set_countries, only: %i[ new edit create update ]

  def index
    @local_parameters = policy_scope(LocalParameter)
                          .joins(:country)
                          .includes(:country)
                          .order("countries.name", :name)
                          .paginate(page: params[:page], per_page: RECORDS_PER_PAGE)
  end

  def show
  end

  def new
    @local_parameter = LocalParameter.new(country: default_country)
  end

  def edit
  end

  def create
    @local_parameter = LocalParameter.new(local_parameter_params)

    if @local_parameter.save
      redirect_to local_parameters_path, notice: t("local_parameters.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @local_parameter.update(local_parameter_params)
      redirect_to local_parameters_path, notice: t("local_parameters.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @local_parameter.destroy!
    redirect_to local_parameters_path, notice: t("local_parameters.destroyed")
  end

  private

  def set_local_parameter
    @local_parameter = LocalParameter.find(params[:id])
  end

  def set_countries
    @countries = Country.order(:country_priority, :name)
  end

  # Colombia first: the platform's home jurisdiction and the only one seeded.
  def default_country
    Country.find_by(code: LocalParameter::DEFAULT_COUNTRY_CODE)
  end

  def local_parameter_params
    params.require(:local_parameter).permit(:country_id, :name, :value, :display_name, :description)
  end
end
