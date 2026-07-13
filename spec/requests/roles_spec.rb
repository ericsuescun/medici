require 'rails_helper'

RSpec.describe "Roles (admin role manager)", type: :request do
  let(:role) { Role.find_by!(name: "trial_center_branch_rep") }

  context "as a non-admin" do
    before { sign_in(FactoryBot.create(:user, :sponsor_rep), scope: :user) }

    it "is blocked from the roles index" do
      get roles_path
      expect(response).to have_http_status(:redirect)
    end

    it "is blocked from updating a role" do
      patch role_path(role), params: { role: { role_permissions_attributes: {} } }
      expect(response).to have_http_status(:redirect)
    end

    it "is blocked from creating a role" do
      post roles_path, params: { role: { name: "auditor", display_name: "Auditor" } }
      expect(response).to have_http_status(:redirect)
      expect(Role.exists?(name: "auditor")).to be(false)
    end
  end

  context "as an admin" do
    before { sign_in(FactoryBot.create(:user, :admin), scope: :user) }

    it "can view the roles index" do
      get roles_path
      expect(response).to be_successful
    end

    it "can open a role's permission editor" do
      get edit_role_path(role)
      expect(response).to be_successful
    end

    it "can open the new-role form" do
      get new_role_path
      expect(response).to be_successful
    end

    it "creates a role and continues to its permission editor" do
      expect do
        post roles_path, params: {
          role: { name: "auditor", display_name: "Auditor", description: "Solo lectura" }
        }
      end.to change(Role, :count).by(1)

      expect(response).to redirect_to(edit_role_path(Role.find_by!(name: "auditor")))
    end

    it "creates a role with all permissions off when nothing is cloned" do
      post roles_path, params: { role: { name: "auditor", display_name: "Auditor" } }

      new_role = Role.find_by!(name: "auditor")
      expect(new_role.role_permissions).to be_empty
      expect(new_role.permits?(Patient, :can_show)).to be(false)
      expect(new_role.permits?(Study, :can_show)).to be(false)
    end

    it "clones permissions from a chosen role when requested" do
      admin_role = Role.find_by!(name: "admin")

      post roles_path, params: {
        role: { name: "auditor", display_name: "Auditor" },
        clone_from_role_id: admin_role.id
      }

      new_role = Role.find_by!(name: "auditor")
      expect(new_role.role_permissions.count).to eq(admin_role.role_permissions.count)
      expect(new_role.permits?(Patient, :can_delete)).to be(true) # copied from admin
    end

    it "updating a permission takes effect on the role" do
      expect(Role.find(role.id).permits?(Sponsor, :can_show)).to be(false)
      perm = role.role_permissions.find_or_create_by!(resource: "Sponsor")

      patch role_path(role), params: {
        role: {
          role_permissions_attributes: {
            "0" => { id: perm.id, resource: "Sponsor", can_show: "1", can_edit: "0", can_delete: "0" }
          }
        }
      }

      expect(response).to redirect_to(roles_path)
      expect(Role.find(role.id).permits?(Sponsor, :can_show)).to be(true)
    end
  end
end
