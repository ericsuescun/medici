require "rails_helper"

RSpec.describe "robots.txt and sitemap.xml", type: :request do
  describe "GET /robots.txt" do
    it "keeps the participation form and the staff area out of the index" do
      get robots_path

      expect(response).to be_successful
      expect(response.media_type).to eq("text/plain")
      expect(response.body).to include("Disallow: /studies/*/participate")
      expect(response.body).to include("Disallow: /users/")
    end

    it "points at the sitemap on whatever host served the request" do
      get robots_path

      expect(response.body).to include("Sitemap: http://www.example.com/sitemap.xml")
    end
  end

  describe "GET /sitemap.xml" do
    it "lists the home page and every public study page" do
      study = FactoryBot.create(:study)

      get sitemap_path

      expect(response).to be_successful
      expect(response.media_type).to eq("application/xml")
      expect(response.body).to include("http://www.example.com/")
      expect(response.body).to include("http://www.example.com#{study_about_path(study)}")
    end

    it "never lists the participation form" do
      study = FactoryBot.create(:study)

      get sitemap_path

      expect(response.body).not_to include(new_participation_request_path(study_id: study.id))
    end
  end
end
