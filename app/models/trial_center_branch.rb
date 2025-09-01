# == Schema Information
#
# Table name: trial_center_branches
#
#  id                       :bigint           not null, primary key
#  name                     :string
#  initials                 :string
#  email                    :string
#  description              :string
#  contact_number           :string
#  contact_address          :string
#  url                      :string
#  trial_center_facility_id :bigint           not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_trial_center_branches_on_trial_center_facility_id  (trial_center_facility_id)
#
# Foreign Keys
#
#  fk_rails_...  (trial_center_facility_id => trial_center_facilities.id)
#
class TrialCenterBranch < ApplicationRecord
  belongs_to :trial_center_facility

  has_and_belongs_to_many :studies
  has_and_belongs_to_many :cities
  has_many :trial_center_branch_reps, dependent: :nullify
end
