class AddIdNumberToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :id_number, :string, default: ""
    add_column :users, :id_type, :string, default: ""
  end
end
