class CreateLocalParameters < ActiveRecord::Migration[8.0]
  # Country-specific configuration the app must not hardcode: the name of the
  # local health authority (INVIMA in Colombia, ANMAT in Argentina, …) and
  # whatever else turns out to differ per jurisdiction. Admin-managed reference
  # data — see LocalParameter / LocalParametersController.
  def change
    create_table :local_parameters do |t|
      t.references :country, null: false, foreign_key: true
      t.string :name, null: false
      t.string :value, null: false
      t.string :display_name
      t.string :description

      t.timestamps
    end

    # One value per parameter name per country.
    add_index :local_parameters, [ :country_id, :name ], unique: true
  end
end
