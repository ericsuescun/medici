class CreateTrialCities < ActiveRecord::Migration[8.0]
  def change
    create_table :trial_cities do |t|
      t.references :studies, null: false, foreign_key: true
      t.string :name

      t.timestamps
    end
  end
end
