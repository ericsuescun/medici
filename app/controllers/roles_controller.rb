class RolesController < SecureApplicationController
  before_action :set_role, only: %i[edit update]

  # index/new/create/edit/update are authorized generically by
  # ResourceAuthorization -> RolePolicy (admin-only). Role is deliberately
  # outside the permission matrix.
  def index
    @roles = Role.order(:name)
  end

  def new
    @role = Role.new
    @roles = Role.order(:name)
  end

  def create
    @role = Role.new(role_attributes_params)
    clone_permissions_into(@role, params[:clone_from_role_id])

    if @role.save
      redirect_to edit_role_path(@role), notice: t("roles.created")
    else
      @roles = Role.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    build_missing_permissions
  end

  def update
    if @role.update(role_params)
      redirect_to roles_path, notice: t("roles.updated")
    else
      build_missing_permissions
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_role
    @role = Role.find(params[:id])
  end

  # Build a row for every managed resource that doesn't have a saved permission
  # yet, so the form always shows the full matrix. (Display order is handled in
  # the view.)
  def build_missing_permissions
    existing = @role.role_permissions.map(&:resource)
    (PermissionCatalog::RESOURCES - existing).each do |resource|
      @role.role_permissions.build(resource: resource)
    end
  end

  # Attributes set when creating a role.
  def role_attributes_params
    params.require(:role).permit(:name, :display_name, :description)
  end

  # Optionally seed the new role by copying another role's permissions. Built on
  # the (unsaved) role so it's persisted atomically with `@role.save`.
  def clone_permissions_into(role, source_role_id)
    return if source_role_id.blank?

    source = Role.find_by(id: source_role_id)
    return unless source

    source.role_permissions.each do |permission|
      role.role_permissions.build(
        resource: permission.resource,
        can_show: permission.can_show,
        can_edit: permission.can_edit,
        can_delete: permission.can_delete
      )
    end
  end

  # Permission matrix edited on the edit/update screen.
  def role_params
    params.require(:role).permit(
      role_permissions_attributes: %i[id resource can_show can_edit can_delete]
    )
  end
end
