require 'rails_helper'

# Exercises the generic, permission-driven ApplicationPolicy through a concrete
# per-resource policy against the seeded default matrix (Medication: admin full;
# patient/sponsor_rep show-only).
RSpec.describe MedicationPolicy do
  subject { described_class }

  let(:admin) { FactoryBot.create(:user, :admin) }
  let(:patient) { FactoryBot.create(:user, :patient) }
  let(:sponsor_rep) { FactoryBot.create(:user, :sponsor_rep) }

  permissions :index?, :show? do
    it "permits roles with can_show" do
      expect(subject).to permit(admin, Medication)
      expect(subject).to permit(patient, Medication)
      expect(subject).to permit(sponsor_rep, Medication)
    end

    it "denies an anonymous user" do
      expect(subject).not_to permit(nil, Medication)
    end
  end

  permissions :new?, :create?, :edit?, :update? do
    it "permits only roles with can_edit" do
      expect(subject).to permit(admin, Medication)
      expect(subject).not_to permit(patient, Medication)
      expect(subject).not_to permit(sponsor_rep, Medication)
    end
  end

  permissions :destroy? do
    it "permits only roles with can_delete" do
      expect(subject).to permit(admin, Medication)
      expect(subject).not_to permit(patient, Medication)
    end
  end
end
