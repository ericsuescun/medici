# == Schema Information
#
# Table name: trial_center_branch_reps
#
#  id                     :bigint           not null, primary key
#  contact_address        :string
#  contact_number         :string
#  title                  :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  trial_center_branch_id :bigint
#
# Indexes
#
#  index_trial_center_branch_reps_on_trial_center_branch_id  (trial_center_branch_id)
#
# Foreign Keys
#
#  fk_rails_...  (trial_center_branch_id => trial_center_branches.id)
#
class TrialCenterBranchRep < ApplicationRecord
  include Userable
  include DelegatesIdentityToUser

  belongs_to :trial_center_branch
end
