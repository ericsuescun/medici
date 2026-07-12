class RolesController < SecureApplicationController
  before_action :set_role, only: %i[edit update]

  # index/edit/update are authorized generically by ResourceAuthorization ->
  # RolePolicy (admin-only). Role is deliberately outside the permission matrix.
  def index
    @roles = Role.order(:name)
  end

  def edit
    build_missing_permissions
  end

  def update
    if @role.update(role_params)
      redirect_to roles_path, notice: "Permisos del rol actualizados correctamente."
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

  def role_params
    params.require(:role).permit(
      role_permissions_attributes: %i[id resource can_show can_edit can_delete]
    )
  end
end
