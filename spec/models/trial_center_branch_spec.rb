# == Schema Information
#
# Table name: trial_center_branches
#
#  id                       :bigint           not null, primary key
#  contact_address          :string
#  contact_number           :string
#  description              :string
#  email                    :string
#  initials                 :string
#  name                     :string
#  url                      :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  trial_center_facility_id :bigint           not null
#
# Indexes
#
#  index_trial_center_branches_on_trial_center_facility_id  (trial_center_facility_id)
#
# Foreign Keys
#
#  fk_rails_...  (trial_center_facility_id => trial_center_facilities.id)
#
require 'rails_helper'

RSpec.describe TrialCenterBranch, type: :model do
  describe "associations" do
    it { should belong_to(:trial_center_facility) }
    it { should have_and_belong_to_many(:studies) }
    it { should have_and_belong_to_many(:cities) }
  end

  describe "database columns" do
    it { should have_db_column(:name).of_type(:string) }
    it { should have_db_column(:initials).of_type(:string) }
    it { should have_db_column(:email).of_type(:string) }
    it { should have_db_column(:description).of_type(:string) }
    it { should have_db_column(:contact_number).of_type(:string) }
    it { should have_db_column(:contact_address).of_type(:string) }
    it { should have_db_column(:url).of_type(:string) }
    it { should have_db_column(:trial_center_facility_id).of_type(:integer).with_options(null: false) }
    it { should have_db_column(:created_at).of_type(:datetime) }
    it { should have_db_column(:updated_at).of_type(:datetime) }
  end

  describe "database indexes" do
    it { should have_db_index(:trial_center_facility_id) }
  end
end
