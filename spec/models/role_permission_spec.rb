require 'rails_helper'

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
RSpec.describe RolePermission, type: :model do
  it { is_expected.to belong_to(:role) }
  it { is_expected.to validate_presence_of(:resource) }
  it { is_expected.to validate_inclusion_of(:resource).in_array(PermissionCatalog::RESOURCES) }

  it "rejects a duplicate resource within the same role" do
    role = Role.find_by!(name: "admin") # already has a Patient permission from seeding
    duplicate = role.role_permissions.build(resource: "Patient", can_show: true)
    expect(duplicate).not_to be_valid
  end
end
