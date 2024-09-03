class CreateContacts < ActiveRecord::Migration[7.2]
  def change
    create_table :contacts do |t|
      t.string :firstname, default: ""
      t.string :lastname, default: ""
      t.string :address1, default: ""
      t.string :number1, default: ""
      t.string :email1, default: ""
      t.text :comments, default: ""
      t.string :title1, default: ""
      t.string :url, default: ""
      t.references :study, null: false, foreign_key: true

      t.timestamps
    end
  end
end
