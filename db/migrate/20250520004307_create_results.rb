class CreateResults < ActiveRecord::Migration[8.0]
  def change
    create_table :results do |t|
      t.references :study, null: false, foreign_key: true
      t.string :result_type
      t.string :title
      t.string :description

      t.timestamps
    end
  end
end
