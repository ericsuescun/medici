class CreatePatients < ActiveRecord::Migration[7.2]
  def change
    create_table :patients do |t|
      t.references :users, null: false, foreign_key: true
      t.string :firstname
      t.string :lastname
      t.date :dob
      t.string :contact_number
      t.string :contact_address
      t.string :email

      t.timestamps
    end
  end
end
