class AddQualitativeFieldsToCriteriaVariables < ActiveRecord::Migration[8.0]
  def change
    add_column :criteria_variables, :qualitative_scale, :text, array: true, default: [], null: false
    add_column :criteria_variables, :qualitative_value, :string
  end
end
