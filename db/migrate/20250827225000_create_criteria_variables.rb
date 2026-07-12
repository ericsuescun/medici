class CreateCriteriaVariables < ActiveRecord::Migration[8.0]
  def change
    create_table :criteria_variables do |t|
      t.string :name, null: false
      t.text :description

      # type of variable (boolean or quantitative)
      t.string :variable_type, null: false

      # quantitative reference values for comparisons/ranges
      t.decimal :reference_value_1, precision: 15, scale: 6
      t.decimal :reference_value_2, precision: 15, scale: 6

      # comparison strategy
      t.string :comparison_type, null: false

      t.text :conditions

      t.references :criteria_profile, null: false, foreign_key: true

      t.timestamps
    end

    add_index :criteria_variables, [ :criteria_profile_id, :name ]
  end
end
