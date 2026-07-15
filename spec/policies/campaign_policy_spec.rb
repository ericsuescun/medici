require 'rails_helper'

RSpec.describe CampaignPolicy, type: :policy do
  subject { described_class }

  let(:campaign) { create(:campaign) }

  permissions :index?, :show? do
    it "allows every role to view" do
      %i[platform_staff sponsor_rep patient trial_center_branch_rep admin].each do |role|
        expect(subject).to permit(create(:user, role), campaign)
      end
    end
  end

  permissions :create?, :update? do
    it "allows platform_staff, sponsor_rep and admin" do
      %i[platform_staff sponsor_rep admin].each do |role|
        expect(subject).to permit(create(:user, role), campaign)
      end
    end

    it "denies patient and trial_center_branch_rep" do
      %i[patient trial_center_branch_rep].each do |role|
        expect(subject).not_to permit(create(:user, role), campaign)
      end
    end
  end

  permissions :destroy? do
    it "allows only platform_staff and admin" do
      %i[platform_staff admin].each do |role|
        expect(subject).to permit(create(:user, role), campaign)
      end
    end

    it "denies sponsor_rep, patient and trial_center_branch_rep" do
      %i[sponsor_rep patient trial_center_branch_rep].each do |role|
        expect(subject).not_to permit(create(:user, role), campaign)
      end
    end
  end
end
