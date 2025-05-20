json.extract! contact, :id, :firstname, :lastname, :address1, :number1, :email1, :comments, :title1, :url, :studies_id, :created_at, :updated_at
json.url contact_url(contact, format: :json)
