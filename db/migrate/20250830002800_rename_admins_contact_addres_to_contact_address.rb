class RenameAdminsContactAddresToContactAddress < ActiveRecord::Migration[8.0]
  def up
    if column_exists?(:admins, :contact_addres) && !column_exists?(:admins, :contact_address)
      rename_column :admins, :contact_addres, :contact_address
    elsif column_exists?(:admins, :contact_addres) && column_exists?(:admins, :contact_address)
      # Edge case: both columns exist; prefer keeping contact_address and drop the misspelled one
      remove_column :admins, :contact_addres
    end
  end

  def down
    if column_exists?(:admins, :contact_address) && !column_exists?(:admins, :contact_addres)
      rename_column :admins, :contact_address, :contact_addres
    end
  end
end
