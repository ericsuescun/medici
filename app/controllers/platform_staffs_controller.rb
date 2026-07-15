class PlatformStaffsController < SecureApplicationController
  before_action :set_platform_staff, only: %i[ show edit update destroy ]

  def index
    @platform_staffs = PlatformStaff.includes(:user).paginate(page: params[:page], per_page: RECORDS_PER_PAGE)
  end

  def show
  end

  def new
    @platform_staff = PlatformStaff.new
    @platform_staff.build_user
  end

  def edit
    @platform_staff.build_user unless @platform_staff.user
  end

  def create
    @platform_staff = PlatformStaff.new(platform_staff_params)

    respond_to do |format|
      if @platform_staff.save
        format.html { redirect_to platform_staff_url(@platform_staff), notice: t("platform_staffs.created") }
        format.json { render :show, status: :created, location: @platform_staff }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @platform_staff.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @platform_staff.update(platform_staff_params)
        format.html { redirect_to platform_staff_url(@platform_staff), notice: t("platform_staffs.updated") }
        format.json { render :show, status: :ok, location: @platform_staff }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @platform_staff.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @platform_staff.destroy!

    respond_to do |format|
      format.html { redirect_to platform_staffs_url, notice: t("platform_staffs.destroyed") }
      format.json { head :no_content }
    end
  end

  private
    def set_platform_staff
      @platform_staff = PlatformStaff.find(params[:id])
    end

    def platform_staff_params
      params.require(:platform_staff).permit(:contact_number, :contact_address, :title,
                                             user_attributes: [ :id, :firstname, :lastname, :email, :password, :password_confirmation ])
    end
end
