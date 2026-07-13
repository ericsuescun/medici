require 'rails_helper'

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
RSpec.describe Role, type: :model do
  let(:admin) { Role.find_by!(name: "admin") }
  let(:patient) { Role.find_by!(name: "patient") }

  describe "#permits?" do
    it "is true when the role has the permission" do
      expect(admin.permits?(Patient, :can_delete)).to be(true)
      expect(patient.permits?(Study, :can_show)).to be(true)
    end

    it "is false when the role lacks the permission" do
      expect(patient.permits?(Study, :can_edit)).to be(false)
      expect(patient.permits?(Patient, :can_show)).to be(false)
    end

    it "accepts a Class or a class-name string" do
      expect(admin.permits?("Patient", :can_show)).to be(true)
    end

    it "is false for an unknown action" do
      expect(admin.permits?(Patient, :can_frobnicate)).to be(false)
    end

    it "is false for a resource with no permission row" do
      expect(patient.permits?(Sponsor, :can_show)).to be(false)
    end
  end
end
