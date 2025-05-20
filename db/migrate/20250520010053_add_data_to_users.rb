class AddDataToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :dob, :date
    add_column :users, :contact_number, :string
    add_column :users, :contact_address, :string
  end
end
