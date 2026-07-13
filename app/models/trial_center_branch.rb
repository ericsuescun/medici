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
class TrialCenterBranch < ApplicationRecord
  belongs_to :trial_center_facility

  has_and_belongs_to_many :studies
  has_and_belongs_to_many :cities
  has_many :trial_center_branch_reps, dependent: :nullify
end
