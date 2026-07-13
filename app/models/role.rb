# == Schema Information
#
# Table name: roles
#
#  id           :bigint           not null, primary key
#  description  :string           default(""), not null
#  display_name :string           default(""), not null
#  name         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_roles_on_name  (name) UNIQUE
#
class Role < ApplicationRecord
  has_many :role_permissions, dependent: :destroy
  has_many :users, dependent: :restrict_with_error

  accepts_nested_attributes_for :role_permissions

  validates :name, presence: true, uniqueness: true
  validates :display_name, presence: true

  # Does this role permit `action` (:can_show/:can_edit/:can_delete) on `resource`
  # (a model Class or its class-name string)? `detect` loads role_permissions
  # once and then reads from the in-memory association (no N+1 across the many
  # policy checks on a page), and stays correct after `reload`.
  def permits?(resource, action)
    return false unless PermissionCatalog::ACTIONS.include?(action)

    resource_name = resource.is_a?(Class) ? resource.name : resource.to_s
    permission = role_permissions.detect { |rp| rp.resource == resource_name }
    permission ? permission.public_send(action) : false
  end
end
