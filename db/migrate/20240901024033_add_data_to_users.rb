class AddDataToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :dob, :date
    add_column :users, :contact_number, :string, default: ""
    add_column :users, :contact_address, :string, default: ""
  end
end
