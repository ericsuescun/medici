class AddIdNumberToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :id_number, :string, default: ""
    add_column :users, :id_type, :string, default: ""
  end
end
