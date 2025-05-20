json.extract! user, :id, :firstname, :lastname, :user_type, :email, :created_at, :updated_at
json.url user_url(user, format: :json)
