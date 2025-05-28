class CreateJoinTableCitiesTrialCenterBranches < ActiveRecord::Migration[8.0]
  def change
    create_join_table :cities, :trial_center_branches do |t|
      # t.index [:city_id, :trial_center_branch_id]
      # t.index [:trial_center_branch_id, :city_id]
    end
  end
end
