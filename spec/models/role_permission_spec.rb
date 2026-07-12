require 'rails_helper'

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
