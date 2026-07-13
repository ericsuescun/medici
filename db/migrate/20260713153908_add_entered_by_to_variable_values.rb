class AddEnteredByToVariableValues < ActiveRecord::Migration[8.0]
  def change
    # Who captured this patient value. Nullable: existing rows predate attribution,
    # and a value may be seeded/imported without a signed-in user.
    add_reference :variable_values, :entered_by, null: true,
                  foreign_key: { to_table: :users }, index: true
  end
end
