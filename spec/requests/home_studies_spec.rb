require 'rails_helper'

RSpec.describe "Home page study showcase", type: :request do
  it "shows all studies with an enroll link to anonymous potential patients" do
    study = FactoryBot.create(:study)

    get root_path

    expect(response).to be_successful
    expect(response.body).to include("Estudios Clínicos Disponibles")
    expect(response.body).to include(study.public_title)
    # The CTA now goes to the participation form (contact details, no account),
    # not to Devise sign-up — that route no longer exists.
    expect(response.body).to include(new_participation_request_path(study_id: study.id))
  end

  it "renders the mobile-first hero: tagline, stat pills, and the login button at the end" do
    get root_path

    expect(response.body).to include("Te ayudamos a encontrar un estudio")
    expect(response.body).to include("stat-pill")
    expect(response.body).to include("Ingreso para usuario")
  end

  it "offers a pill per category in use plus an all-studies pill" do
    derm = FactoryBot.create(:category, name: "Dermatología")
    onco = FactoryBot.create(:category, name: "Oncología")
    FactoryBot.create(:study).categories << derm
    FactoryBot.create(:study).categories << onco
    FactoryBot.create(:category, name: "Sin estudios aún")

    get root_path

    expect(response.body).to include("Todos los estudios")
    expect(response.body).to include("Dermatología")
    expect(response.body).to include("Oncología")
    # A category no study uses yet gets no pill.
    expect(response.body).not_to include("Sin estudios aún")
  end

  it "filters the showcase when a category pill is followed" do
    derm = FactoryBot.create(:category, name: "Dermatología")
    onco = FactoryBot.create(:category, name: "Oncología")
    derm_study = FactoryBot.create(:study)
    onco_study = FactoryBot.create(:study)
    derm_study.categories << derm
    onco_study.categories << onco

    get root_path(category: derm.id)

    expect(response).to be_successful
    expect(response.body).to include(derm_study.public_title)
    expect(response.body).not_to include(onco_study.public_title)
  end

  it "keeps categoryless studies visible in the unfiltered showcase" do
    bare = FactoryBot.create(:study)

    get root_path

    expect(response.body).to include(bare.public_title)
  end

  it "falls back to all studies on an unknown category id" do
    study = FactoryBot.create(:study, :with_categories)

    get root_path(category: 999_999)

    expect(response).to be_successful
    expect(response.body).to include(study.public_title)
  end
end
