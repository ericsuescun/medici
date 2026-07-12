require 'rails_helper'

RSpec.describe PatientPolicy do
  subject { described_class }

  let(:admin) { FactoryBot.create(:user, :admin) }
  let(:trial_rep) { FactoryBot.create(:user, :trial_center_branch_rep) }
  let(:patient_user) { FactoryBot.create(:user, :patient) }
  let(:sponsor_rep) { FactoryBot.create(:user, :sponsor_rep) }
  let(:record) { FactoryBot.create(:patient) }

  permissions :show_state?, :update_state? do
    it "permits admins and trial center reps" do
      expect(subject).to permit(admin, record)
      expect(subject).to permit(trial_rep, record)
    end

    it "denies patients, sponsor reps, and anonymous users" do
      expect(subject).not_to permit(patient_user, record)
      expect(subject).not_to permit(sponsor_rep, record)
      expect(subject).not_to permit(nil, record)
    end
  end

  permissions :assess? do
    it "permits an authorized role when the AASM guard allows it" do
      expect(subject).to permit(admin, record) # prospect => may_assess? true
    end

    it "denies when the AASM guard forbids the transition" do
      record.assess! # now candidate => may_assess? false
      expect(subject).not_to permit(admin, record)
    end

    it "denies unauthorized roles even when the guard allows it" do
      expect(subject).not_to permit(patient_user, record)
    end
  end

  permissions :accept? do
    it "denies an admin while the patient is still prospect" do
      expect(subject).not_to permit(admin, record) # may_accept? false from prospect
    end

    it "permits an admin once the patient is a candidate" do
      record.assess!
      expect(subject).to permit(admin, record)
    end
  end
end
