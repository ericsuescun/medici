json.extract! contact, :id, :firstname, :lastname, :address1, :address2, :number1, :number2, :email1, :email2, :comments, :title1, :title2, :url, :studies_id, :created_at, :updated_at
json.url contact_url(contact, format: :json)
