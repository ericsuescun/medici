require 'rails_helper'

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
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
end
