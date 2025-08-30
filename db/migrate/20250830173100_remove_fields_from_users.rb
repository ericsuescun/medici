class RemoveFieldsFromUsers < ActiveRecord::Migration[7.0]
  def up
    remove_column :users, :contact_address, :string if column_exists?(:users, :contact_address)
    remove_column :users, :contact_number, :string if column_exists?(:users, :contact_number)
    remove_column :users, :user_type, :string if column_exists?(:users, :user_type)
    remove_column :users, :id_number, :string if column_exists?(:users, :id_number)
    remove_column :users, :id_type, :string if column_exists?(:users, :id_type)
  end

  def down
    add_column :users, :contact_address, :string, default: "" unless column_exists?(:users, :contact_address)
    add_column :users, :contact_number, :string, default: "" unless column_exists?(:users, :contact_number)
    add_column :users, :user_type, :string unless column_exists?(:users, :user_type)
    add_column :users, :id_number, :string, default: "" unless column_exists?(:users, :id_number)
    add_column :users, :id_type, :string, default: "" unless column_exists?(:users, :id_type)
  end
end
