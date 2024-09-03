class CreateResults < ActiveRecord::Migration[7.2]
  def change
    create_table :results do |t|
      t.references :study, null: false, foreign_key: true
      t.string :result_type, default: ""
      t.string :title, default: ""
      t.string :description, default: ""

      t.timestamps
    end
  end
end
