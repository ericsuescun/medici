class CriteriaVariablesController < SecureApplicationController
  before_action :set_criteria_profile
  before_action :set_criteria_variable, only: %i[ show edit update destroy ]

  # GET /criteria_profiles/:criteria_profile_id/criteria_variables
  def index
    # Order inclusion first, then exclusion, and within each group by most recent
    @criteria_variables = @criteria_profile.criteria_variables.order(Arel.sql("CASE criteria_variables.variable_type WHEN 'inclusion' THEN 0 ELSE 1 END, COALESCE(criteria_variables.criteria_order, 2147483647) ASC, created_at DESC"))
  end

  # GET /criteria_profiles/:criteria_profile_id/criteria_variables/:id
  def show
  end

  # GET /criteria_profiles/:criteria_profile_id/criteria_variables/new
  def new
    @criteria_variable = @criteria_profile.criteria_variables.build
    # Default variable_type and suggested order within its group
    @criteria_variable.variable_type ||= "inclusion"
    @criteria_variable.criteria_order ||= next_criteria_order(@criteria_variable.variable_type)
  end

  # GET /criteria_profiles/:criteria_profile_id/criteria_variables/:id/edit
  def edit
    # Suggest an order only if not already set
    if @criteria_variable.criteria_order.nil?
      @criteria_variable.criteria_order = next_criteria_order(@criteria_variable.variable_type)
    end
  end

  # POST /criteria_profiles/:criteria_profile_id/criteria_variables
  def create
    @criteria_variable = @criteria_profile.criteria_variables.build(criteria_variable_params)

    respond_to do |format|
      if @criteria_variable.save
        format.html { redirect_to criteria_profile_criteria_variable_url(@criteria_profile, @criteria_variable), notice: t("criteria_variables.flash.created") }
        format.json { render :show, status: :created, location: criteria_profile_criteria_variable_url(@criteria_profile, @criteria_variable) }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @criteria_variable.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /criteria_profiles/:criteria_profile_id/criteria_variables/:id
  def update
    Rails.logger.info "Received params: #{params.inspect}"
    Rails.logger.info "Permitted params: #{criteria_variable_params.inspect}"


    respond_to do |format|
      if @criteria_variable.update(criteria_variable_params)
        format.html { redirect_to criteria_profile_criteria_variable_url(@criteria_profile, @criteria_variable), notice: t("criteria_variables.flash.updated") }
        format.json { render :show, status: :ok, location: criteria_profile_criteria_variable_url(@criteria_profile, @criteria_variable) }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @criteria_variable.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /criteria_profiles/:criteria_profile_id/criteria_variables/:id
  def destroy
    @criteria_variable.destroy!

    respond_to do |format|
      format.html { redirect_to criteria_profile_criteria_variables_url(@criteria_profile), notice: t("criteria_variables.flash.destroyed") }
      format.json { head :no_content }
    end
  end

  private
    def next_criteria_order(variable_type)
      scope = @criteria_profile.criteria_variables.where(variable_type: variable_type)
      # consider only non-nil orders; if none, start from 1
      max = scope.where.not(criteria_order: nil).maximum(:criteria_order)
      (max || 0) + 1
    end

    def set_criteria_profile
      # Ensure users can only access their own profiles' variables
      @criteria_profile = CriteriaProfile.where(user: current_user).find(params[:criteria_profile_id])
    end

    def set_criteria_variable
      @criteria_variable = @criteria_profile.criteria_variables.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def criteria_variable_params
      params.require(:criteria_variable).permit(
        :name, :description, :value_type, :variable_type, :reference_value_1, :reference_value_2, :comparison_type, :conditions,
        :qualitative_value, :qualitative_scale, :enabled, :shown, :criteria_order
      )
    end
end
