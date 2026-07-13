class AddRoleToUsers < ActiveRecord::Migration[8.0]
  def change
    # Nullable for now so existing users can be backfilled; a later migration
    # (once every creation path assigns a role) enforces NOT NULL.
    add_reference :users, :role, null: true, foreign_key: true, index: true
  end
end
