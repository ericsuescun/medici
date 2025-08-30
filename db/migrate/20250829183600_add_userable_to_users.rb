class AddUserableToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :userable_type, :string
    add_column :users, :userable_id, :bigint
    add_index :users, [:userable_type, :userable_id]
  end
end