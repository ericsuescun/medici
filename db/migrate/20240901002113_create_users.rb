class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :firstname, default: ""
      t.string :lastname,  default: ""
      t.string :user_type

      t.timestamps
    end
  end
end
