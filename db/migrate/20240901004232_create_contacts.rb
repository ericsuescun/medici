class CreateContacts < ActiveRecord::Migration[7.2]
  def change
    create_table :contacts do |t|
      t.string :firstname
      t.string :lastname
      t.string :address1
      t.string :address2
      t.string :number1
      t.string :number2
      t.string :email1
      t.string :email2
      t.text :comments
      t.string :title1
      t.string :title2
      t.string :url
      t.references :studies, null: false, foreign_key: true

      t.timestamps
    end
  end
end
