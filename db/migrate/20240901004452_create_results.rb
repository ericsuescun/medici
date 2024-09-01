class CreateResults < ActiveRecord::Migration[7.2]
  def change
    create_table :results do |t|
      t.references :studies, null: false, foreign_key: true
      t.string :result_type
      t.string :title
      t.string :description

      t.timestamps
    end
  end
end
