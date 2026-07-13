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
  end

  def create
    @role = Role.new(role_attributes_params)
    if @role.save
      redirect_to edit_role_path(@role), notice: "Rol creado. Ahora configura sus permisos."
    else
      render :new, status: :unprocessable_entity
    end
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

  # Attributes set when creating a role.
  def role_attributes_params
    params.require(:role).permit(:name, :display_name, :description)
  end

  # Permission matrix edited on the edit/update screen.
  def role_params
    params.require(:role).permit(
      role_permissions_attributes: %i[id resource can_show can_edit can_delete]
    )
  end
end
