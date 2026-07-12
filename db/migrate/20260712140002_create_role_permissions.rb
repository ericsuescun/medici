class CreateRolePermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :role_permissions do |t|
      t.references :role, null: false, foreign_key: true
      t.string :resource, null: false
      t.boolean :can_show, null: false, default: false
      t.boolean :can_edit, null: false, default: false
      t.boolean :can_delete, null: false, default: false

      t.timestamps
    end

    add_index :role_permissions, [ :role_id, :resource ], unique: true
  end
end
