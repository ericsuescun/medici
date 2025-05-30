class CreateTrialCenterBranches < ActiveRecord::Migration[8.0]
  def change
    create_table :trial_center_branches do |t|
      t.string :name
      t.string :initials
      t.string :email
      t.string :description
      t.string :contact_number
      t.string :contact_address
      t.string :url
      t.references :trial_center_facility, null: false, foreign_key: true

      t.timestamps
    end
  end
end
