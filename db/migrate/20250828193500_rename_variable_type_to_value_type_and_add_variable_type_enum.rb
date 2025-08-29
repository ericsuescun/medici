class RenameVariableTypeToValueTypeAndAddVariableTypeEnum < ActiveRecord::Migration[7.1]
  def up
    # Rename existing variable_type to value_type
    rename_column :criteria_variables, :variable_type, :value_type

    # Add new variable_type for inclusion/exclusion
    add_column :criteria_variables, :variable_type, :string, null: false, default: 'inclusion'

    # Optional: add a check or index if desired (skipped for minimal change)
  end

  def down
    # Remove new variable_type
    remove_column :criteria_variables, :variable_type

    # Rename value_type back to variable_type
    rename_column :criteria_variables, :value_type, :variable_type
  end
end
