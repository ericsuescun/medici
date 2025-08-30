class RemoveDobFromUsers < ActiveRecord::Migration[7.0]
  def up
    remove_column :users, :dob, :date if column_exists?(:users, :dob)
  end

  def down
    add_column :users, :dob, :date unless column_exists?(:users, :dob)
  end
end
