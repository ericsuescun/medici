class AddEnabledAndShownToCriteriaVariables < ActiveRecord::Migration[8.0]
  def change
    add_column :criteria_variables, :enabled, :boolean, null: false, default: true
    add_column :criteria_variables, :shown, :boolean, null: false, default: true
  end
end
