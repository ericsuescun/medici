json.extract! patient, :id, :users_id, :firstname, :lastname, :dob, :contact_number, :contact_address, :email, :created_at, :updated_at
json.url patient_url(patient, format: :json)
