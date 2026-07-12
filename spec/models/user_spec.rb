require 'rails_helper'

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
end
