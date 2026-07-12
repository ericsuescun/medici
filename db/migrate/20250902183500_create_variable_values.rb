class CreateVariableValues < ActiveRecord::Migration[8.0]
  def change
    create_table :variable_values do |t|
      t.string :name, null: false
      t.text :description
      t.string :value_type, null: false
      t.decimal :reference_value_1, precision: 15, scale: 6
      t.decimal :reference_value_2, precision: 15, scale: 6
      t.string :comparison_type, null: false
      t.text :conditions
      t.text :qualitative_scale, array: true, default: [], null: false
      t.string :qualitative_value
      t.string :variable_type, null: false, default: "inclusion"
      t.boolean :enabled, null: false, default: true
      t.boolean :shown, null: false, default: true
      t.integer :criteria_order
      t.references :patient, null: false, foreign_key: true
      t.string :value

      t.timestamps
    end

    add_index :variable_values, [ :patient_id, :variable_type, :criteria_order ], name: :index_vv_on_patient_type_order
    add_index :variable_values, [ :patient_id, :name ]
  end
end
