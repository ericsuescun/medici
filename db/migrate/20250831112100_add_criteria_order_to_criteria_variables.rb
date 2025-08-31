class AddCriteriaOrderToCriteriaVariables < ActiveRecord::Migration[8.0]
  def change
    add_column :criteria_variables, :criteria_order, :integer
    add_index :criteria_variables, [:criteria_profile_id, :variable_type, :criteria_order], name: "index_cv_on_profile_type_order"
  end
end
