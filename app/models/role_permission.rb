# == Schema Information
#
# Table name: role_permissions
#
#  id         :bigint           not null, primary key
#  can_delete :boolean          default(FALSE), not null
#  can_edit   :boolean          default(FALSE), not null
#  can_show   :boolean          default(FALSE), not null
#  resource   :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  role_id    :bigint           not null
#
# Indexes
#
#  index_role_permissions_on_role_id               (role_id)
#  index_role_permissions_on_role_id_and_resource  (role_id,resource) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (role_id => roles.id)
#
class RolePermission < ApplicationRecord
  belongs_to :role

  validates :resource,
            presence: true,
            uniqueness: { scope: :role_id },
            inclusion: { in: PermissionCatalog::RESOURCES }
end
