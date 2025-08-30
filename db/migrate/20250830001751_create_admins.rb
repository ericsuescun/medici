class CreateAdmins < ActiveRecord::Migration[8.0]
  def change
    create_table :admins do |t|
      t.string :contact_number
      t.string :contact_addres
      t.string :title

      t.timestamps
    end
  end
end
