class CreateSponsors < ActiveRecord::Migration[7.2]
  def change
    create_table :sponsors do |t|
      t.string :name
      t.string :intials
      t.string :shortname
      t.string :sponsor_type

      t.timestamps
    end
  end
end
