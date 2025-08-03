class CreateJoinTableStudiesMedications < ActiveRecord::Migration[8.0]
  def change
    create_join_table :studies, :medications do |t|
      t.index [:study_id, :medication_id]
      t.index [:medication_id, :study_id]
    end
  end
end
