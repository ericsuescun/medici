json.extract! article, :id, :title, :description, :url, :studies_id, :created_at, :updated_at
json.url article_url(article, format: :json)
