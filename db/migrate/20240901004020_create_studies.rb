class CreateStudies < ActiveRecord::Migration[7.2]
  def change
    create_table :studies do |t|
      t.references :sponsor, null: false, foreign_key: true
      t.string :study_status
      t.string :local_unique_register, default: ""
      t.string :scientific_title, default: ""
      t.string :public_title, default: ""
      t.date :registered_at
      t.date :approved_at
      t.date :started_at
      t.date :first_patient_at
      t.date :global_ending_at
      t.string :study_type
      t.string :study_phase
      t.string :inclusion_criteria, default: ""
      t.string :exclusion_criteria, default: ""
      t.integer :sample_size
      t.string :main_intervention, default: ""
      t.string :control_group, default: ""
      t.integer :participant_starting_age
      t.integer :participant_ending_age
      t.string :sex, default: ""
      t.string :medical_preexistences, default: ""
      t.string :ethical_committee, default: ""
      t.date :ethical_approval_at
      t.string :keywords, default: ""
      t.string :pathology, default: ""
      t.string :medication, default: ""
      t.boolean :reviewed, default: false
      t.integer :review_user_id

      t.timestamps
    end
  end
end
