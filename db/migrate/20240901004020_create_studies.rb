class CreateStudies < ActiveRecord::Migration[7.2]
  def change
    create_table :studies do |t|
      t.references :sponsors, null: false, foreign_key: true
      t.string :study_status
      t.string :local_unique_register
      t.string :cientific_title
      t.string :public_title
      t.date :registrated_at
      t.date :approved_at
      t.date :started_at
      t.date :first_patient_at
      t.date :global_ending_at
      t.string :study_type
      t.string :study_phase
      t.string :inclusion_criteria
      t.string :exclusion_criteria
      t.integer :sample_size
      t.string :main_intervention
      t.string :control_group
      t.integer :participant_starting_age
      t.integer :participant_ending_age
      t.string :sex
      t.string :medical_preexistencies
      t.string :ethical_cometee
      t.date :ethical_approval_at
      t.string :keywords
      t.string :pathology
      t.string :medication
      t.boolean :reviewed
      t.integer :review_user_id

      t.timestamps
    end
  end
end
