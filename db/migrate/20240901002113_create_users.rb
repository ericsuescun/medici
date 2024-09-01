class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :firstname
      t.string :lastname
      t.string :user_type

      t.timestamps
    end
  end
end
