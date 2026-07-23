class AddActiveToUsers < ActiveRecord::Migration[8.0]
  # Accounts are inactive until an admin activates them (see
  # User#active_for_authentication?): a staff account created through the
  # role-specific controllers cannot sign in until somebody with the admin role
  # switches it on in the activation manager.
  #
  # Backfill deliberately only turns admins on — every other pre-existing
  # account starts inactive and must be activated explicitly, which is the whole
  # point of the gate. Admins keep access so they can do the activating.
  def up
    add_column :users, :active, :boolean, default: false, null: false
    add_index :users, :active

    execute "UPDATE users SET active = TRUE WHERE userable_type = 'Admin'"
  end

  def down
    remove_index :users, :active
    remove_column :users, :active
  end
end
