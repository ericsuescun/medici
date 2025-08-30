class CreateSponsorReps < ActiveRecord::Migration[8.0]
  def change
    create_table :sponsor_reps do |t|
      t.string :contact_number
      t.string :contact_address
      t.string :title

      t.timestamps
    end
  end
end
