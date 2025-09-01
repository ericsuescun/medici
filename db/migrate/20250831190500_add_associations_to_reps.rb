class AddAssociationsToReps < ActiveRecord::Migration[8.0]
  def change
    add_reference :sponsor_reps, :sponsor, foreign_key: true
    add_reference :trial_center_branch_reps, :trial_center_branch, foreign_key: true
  end
end