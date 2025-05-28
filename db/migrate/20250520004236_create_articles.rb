class CreateArticles < ActiveRecord::Migration[8.0]
  def change
    create_table :articles do |t|
      t.string :title
      t.string :description
      t.string :url
      t.references :study, null: false, foreign_key: true

      t.timestamps
    end
  end
end
