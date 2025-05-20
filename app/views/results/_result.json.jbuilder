json.extract! result, :id, :studies_id, :result_type, :title, :description, :created_at, :updated_at
json.url result_url(result, format: :json)
