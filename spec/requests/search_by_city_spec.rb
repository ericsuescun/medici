require 'rails_helper'

RSpec.describe "Search studies by city", type: :request do
  def build_city_with_study
    city = FactoryBot.create(:city)
    branch = FactoryBot.create(:trial_center_branch)
    branch.cities << city
    study = FactoryBot.create(:study)
    study.trial_center_branches << branch
    [ city, branch, study ]
  end

  it "shows matching studies as home-style cards listing the city's trial centers" do
    city, branch, study = build_city_with_study

    get static_pages_search_by_city_path(city_id: city.id)

    expect(response).to be_successful
    expect(response.body).to include("health-card")
    expect(response.body).to include(study.public_title)
    expect(response.body).to include(branch.trial_center_facility.name)
    expect(response.body).to include(branch.name)
    expect(response.body).to include("Centros donde se realiza")
    # Anonymous visitors keep the same CTAs as the home showcase.
    expect(response.body).to include(new_participation_request_path(study_id: study.id))
    expect(response.body).to include("Más sobre este estudio")
  end

  it "sends signed-in staff to the full study page instead of the public card" do
    city, _branch, study = build_city_with_study
    sign_in(FactoryBot.create(:user, :admin), scope: :user)

    get static_pages_search_by_city_path(city_id: city.id)

    expect(response.body).to include(study_path(study))
    expect(response.body).not_to include(new_participation_request_path(study_id: study.id))
  end

  it "keeps the empty state for a city with no studies" do
    city = FactoryBot.create(:city)

    get static_pages_search_by_city_path(city_id: city.id)

    expect(response).to be_successful
    expect(response.body).to include("No se encontraron estudios")
  end
end
