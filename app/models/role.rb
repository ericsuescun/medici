class Role < ApplicationRecord
  has_many :role_permissions, dependent: :destroy
  has_many :users, dependent: :restrict_with_error

  accepts_nested_attributes_for :role_permissions

  validates :name, presence: true, uniqueness: true
  validates :display_name, presence: true

  # Does this role permit `action` (:can_show/:can_edit/:can_delete) on `resource`
  # (a model Class or its class-name string)? Loads role_permissions once and
  # checks in memory to avoid N+1 across the many policy checks on a page.
  def permits?(resource, action)
    return false unless PermissionCatalog::ACTIONS.include?(action)

    name = resource.is_a?(Class) ? resource.name : resource.to_s
    permission = permission_by_resource[name]
    permission ? permission.public_send(action) : false
  end

  private

  def permission_by_resource
    @permission_by_resource ||= role_permissions.index_by(&:resource)
  end
end
