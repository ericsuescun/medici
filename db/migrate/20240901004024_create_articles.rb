class CreateArticles < ActiveRecord::Migration[7.2]
  def change
    create_table :articles do |t|
      t.string :title, default: ""
      t.string :description, default: ""
      t.string :url, default: ""
      t.references :study, null: false, foreign_key: true

      t.timestamps
    end
  end
end
