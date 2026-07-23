require 'rails_helper'

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  active                 :boolean          default(FALSE), not null
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  firstname              :string
#  illness_description    :string           default("")
#  lastname               :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  userable_type          :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  role_id                :bigint
#  userable_id            :bigint
#
# Indexes
#
#  index_users_on_active                         (active)
#  index_users_on_email                          (email) UNIQUE
#  index_users_on_reset_password_token           (reset_password_token) UNIQUE
#  index_users_on_role_id                        (role_id)
#  index_users_on_userable_type_and_userable_id  (userable_type,userable_id)
#
# Foreign Keys
#
#  fk_rails_...  (role_id => roles.id)
#
RSpec.describe User, type: :model do
  describe "default role assignment on create" do
    it "maps each userable type to the matching role" do
      expect(FactoryBot.create(:user, :admin).role&.name).to eq("admin")
      expect(FactoryBot.create(:user, :patient).role&.name).to eq("patient")
      expect(FactoryBot.create(:user, :sponsor_rep).role&.name).to eq("sponsor_rep")
      expect(FactoryBot.create(:user, :trial_center_branch_rep).role&.name)
        .to eq("trial_center_branch_rep")
    end

    it "does not overwrite an explicitly assigned role" do
      custom = Role.find_by!(name: "admin")
      user = FactoryBot.create(:user, :patient, role: custom)
      expect(user.role).to eq(custom)
    end
  end

  describe "activation" do
    it "defaults to inactive for a non-admin account" do
      rep = SponsorRep.create!(sponsor: FactoryBot.create(:sponsor))
      user = User.create!(email: "new-rep@example.com", password: "12345678",
                          firstname: "Ana", lastname: "Ruiz", userable: rep)

      expect(user.active?).to be(false)
      expect(user.active_for_authentication?).to be(false)
      expect(user.inactive_message).to eq(:inactive)
    end

    it "forces admins active, even when created or updated with active: false" do
      user = User.create!(email: "new-admin@example.com", password: "12345678",
                          firstname: "Luis", lastname: "Peña",
                          userable: Admin.create!, active: false)
      expect(user.active?).to be(true)

      user.update!(active: false)
      expect(user.reload.active?).to be(true)
    end

    it "lets an activated non-admin authenticate" do
      user = FactoryBot.create(:user, :sponsor_rep, :inactive)
      expect(user.active_for_authentication?).to be(false)

      user.update!(active: true)
      expect(user.active_for_authentication?).to be(true)
    end

    it "scopes accounts by activation state" do
      active = FactoryBot.create(:user, :sponsor_rep)
      inactive = FactoryBot.create(:user, :sponsor_rep, :inactive)

      expect(User.active).to include(active)
      expect(User.active).not_to include(inactive)
      expect(User.inactive).to contain_exactly(inactive)
    end
  end

  describe "#organization_name" do
    it "returns the sponsor for a sponsor rep and the branch for a branch rep" do
      sponsor = FactoryBot.create(:sponsor, name: "Farma S.A.")
      branch = FactoryBot.create(:trial_center_branch, name: "Sede Norte")

      sponsor_user = FactoryBot.create(:user, userable: FactoryBot.create(:sponsor_rep, sponsor: sponsor))
      branch_user = FactoryBot.create(:user, userable: FactoryBot.create(:trial_center_branch_rep, trial_center_branch: branch))

      expect(sponsor_user.organization_name).to eq("Farma S.A.")
      expect(branch_user.organization_name).to eq("Sede Norte")
      expect(FactoryBot.create(:user, :admin).organization_name).to be_nil
    end
  end
end
