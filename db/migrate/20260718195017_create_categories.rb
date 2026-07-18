class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :categories, :name, unique: true

    create_join_table :categories, :studies do |t|
      t.index [ :category_id, :study_id ], unique: true
      t.index :study_id
    end
  end
end
