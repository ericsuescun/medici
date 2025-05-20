class CreatePatients < ActiveRecord::Migration[8.0]
  def change
    create_table :patients do |t|
      t.string :firstname
      t.string :lastname
      t.date :dob
      t.string :sex
      t.string :contact_number
      t.string :contact_address
      t.string :email
      t.string :notes
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
