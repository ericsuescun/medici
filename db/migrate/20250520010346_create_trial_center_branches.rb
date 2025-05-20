class CreateTrialCenterBranches < ActiveRecord::Migration[8.0]
  def change
    create_table :trial_center_branches do |t|
      t.string :name
      t.string :initials
      t.string :description
      t.references :trial_center_facility, null: false, foreign_key: true

      t.timestamps
    end
  end
end
