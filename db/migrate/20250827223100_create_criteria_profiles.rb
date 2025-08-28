class CreateCriteriaProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :criteria_profiles do |t|
      t.string :name, null: false
      t.text :description
      t.references :study, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :criteria_profiles, [:study_id, :user_id]
  end
end
