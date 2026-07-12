class RolePermission < ApplicationRecord
  belongs_to :role

  validates :resource,
            presence: true,
            uniqueness: { scope: :role_id },
            inclusion: { in: PermissionCatalog::RESOURCES }
end
