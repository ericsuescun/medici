json.extract! patient, :id, :firstname, :lastname, :dob, :sex, :contact_number, :contact_address, :email, :notes, :user_id, :created_at, :updated_at
json.url patient_url(patient, format: :json)
