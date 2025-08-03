json.extract! study, :id, :sponsor_id, :study_status, :scientific_title, :public_title, :completed_at, :started_at, :first_patient_at, :global_ending_at, :study_phase, :inclusion_criteria, :exclusion_criteria, :sample_size, :main_intervention, :sex, :reviewed, :review_user_id, :created_at, :updated_at
json.url study_url(study, format: :json)
