class CreateJoinTableStudiesTrialCenterBranches < ActiveRecord::Migration[8.0]
  def change
    create_join_table :studies, :trial_center_branches do |t|
      # t.index [:study_id, :trial_center_branch_id]
      # t.index [:trial_center_branch_id, :study_id]
    end
  end
end
