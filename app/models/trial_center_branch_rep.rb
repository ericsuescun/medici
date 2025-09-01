class TrialCenterBranchRep < ApplicationRecord
  include Userable

  belongs_to :trial_center_branch, optional: true
end
