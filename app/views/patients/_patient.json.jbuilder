json.extract! patient, :id, :firstname, :lastname, :dob, :sex, :contact_number, :contact_address, :email, :id_type, :id_number, :illness_description, :created_at, :updated_at
json.url patient_url(patient, format: :json)
