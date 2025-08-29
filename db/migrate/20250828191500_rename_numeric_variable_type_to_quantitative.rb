class RenameNumericVariableTypeToQuantitative < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE criteria_variables SET variable_type = 'quantitative' WHERE variable_type = 'numeric';
    SQL
  end

  def down
    execute <<~SQL
      UPDATE criteria_variables SET variable_type = 'numeric' WHERE variable_type = 'quantitative';
    SQL
  end
end
