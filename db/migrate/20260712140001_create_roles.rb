class CreateRoles < ActiveRecord::Migration[8.0]
  def change
    create_table :roles do |t|
      t.string :name, null: false
      t.string :display_name, null: false, default: ""
      t.string :description, null: false, default: ""

      t.timestamps
    end

    add_index :roles, :name, unique: true
  end
end
