# Admin-only account activation manager: lists staff accounts and switches
# `users.active` on or off. An inactive account cannot sign in and is signed out
# of any session it already holds (see User#active_for_authentication?).
class UserActivationsController < SecureApplicationController
  # Account kind -> userable_type. "all" means no type filter.
  TYPES = {
    "admins" => "Admin",
    "platform_staffs" => "PlatformStaff",
    "sponsor_reps" => "SponsorRep",
    "branch_reps" => "TrialCenterBranchRep"
  }.freeze

  STATUSES = %w[all active inactive].freeze

  before_action :authorize_activation_management
  before_action :set_user, only: :update

  def index
    @type = TYPES.key?(params[:type]) ? params[:type] : "all"
    @status = STATUSES.include?(params[:status]) ? params[:status] : "all"
    @sponsor_id = params[:sponsor_id].presence
    @branch_id = params[:trial_center_branch_id].presence
    @query = params[:q].to_s.strip

    @sponsors = Sponsor.order(:name)
    @branches = TrialCenterBranch.order(:name)

    # Counts describe the current selection regardless of the status tab, so the
    # admin can see "8 activos / 3 inactivos" while looking at either list.
    scope = filtered_users
    @active_count = scope.where(active: true).count
    @inactive_count = scope.where(active: false).count

    scope = scope.where(active: @status == "active") unless @status == "all"
    @users = scope.paginate(page: params[:page], per_page: RECORDS_PER_PAGE)
  end

  def update
    activate = ActiveModel::Type::Boolean.new.cast(params[:active])

    if @user.admin? && !activate
      redirect_to redirect_target, alert: t("user_activations.admin_always_active")
      return
    end

    @user.update!(active: activate)
    redirect_to redirect_target,
                notice: t(activate ? "user_activations.activated" : "user_activations.deactivated",
                          name: display_name(@user))
  end

  private

  # No `UserActivation` model exists; authorization is the explicit admin-only
  # check below, so opt out of ResourceAuthorization's generic class authorize.
  def authorization_model
    nil
  end

  def authorize_activation_management
    authorize(User, :manage_activation?)
  end

  def set_user
    @user = User.find(params[:id])
  end

  def filtered_users
    users = User.includes(:role).preload(:userable)
                .order(:userable_type, :lastname, :firstname, :id)

    users = users.where(userable_type: TYPES[@type]) if TYPES.key?(@type)

    # An organisation filter implies the account kind it belongs to, so it wins
    # over a conflicting `type` param rather than silently returning nothing.
    if @sponsor_id
      users = users.where(userable_type: "SponsorRep",
                          userable_id: SponsorRep.where(sponsor_id: @sponsor_id).select(:id))
    end

    if @branch_id
      users = users.where(userable_type: "TrialCenterBranchRep",
                          userable_id: TrialCenterBranchRep.where(trial_center_branch_id: @branch_id).select(:id))
    end

    if @query.present?
      like = "%#{@query.downcase}%"
      users = users.where(
        "LOWER(users.firstname) LIKE :q OR LOWER(users.lastname) LIKE :q OR LOWER(users.email) LIKE :q",
        q: like
      )
    end

    users
  end

  # Keep the admin on the same filtered page after toggling.
  def redirect_target
    user_activations_path(request.query_parameters.except("active"))
  end

  def display_name(user)
    user.fullname.presence || user.email
  end
end
