class CreateTrialCities < ActiveRecord::Migration[7.2]
  def change
    create_table :trial_cities do |t|
      t.references :study, null: false, foreign_key: true
      t.string :name, default: ""

      t.timestamps
    end
  end
end
