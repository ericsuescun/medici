class CreateIdTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :id_types do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.string :country_code, null: false
      t.string :description
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :id_types, [ :country_code, :code ], unique: true
    add_index :id_types, :country_code
    add_index :id_types, :active
  end
end
