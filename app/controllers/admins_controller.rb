class AdminsController < SecureApplicationController
  before_action :set_admin, only: %i[ show edit update destroy ]

  def index
    @admins = Admin.includes(:user).paginate(page: params[:page], per_page: RECORDS_PER_PAGE)
  end

  def show
  end

  def new
    @admin = Admin.new
    @admin.build_user
  end

  def edit
    @admin.build_user unless @admin.user
  end

  def create
    @admin = Admin.new(admin_params)

    respond_to do |format|
      if @admin.save
        format.html { redirect_to admin_url(@admin), notice: t("admins.created") }
        format.json { render :show, status: :created, location: @admin }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @admin.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @admin.update(admin_params)
        format.html { redirect_to admin_url(@admin), notice: t("admins.updated") }
        format.json { render :show, status: :ok, location: @admin }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @admin.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @admin.destroy!

    respond_to do |format|
      format.html { redirect_to admins_url, notice: t("admins.destroyed") }
      format.json { head :no_content }
    end
  end

  private
    def set_admin
      @admin = Admin.find(params[:id])
    end

    def admin_params
      params.require(:admin).permit(:contact_number, :contact_address, :title,
                                    user_attributes: [ :id, :firstname, :lastname, :email, :password, :password_confirmation ])
    end
end
