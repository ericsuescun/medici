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

  it "offers a pill per topic in use plus an all-studies pill" do
    FactoryBot.create(:study, topic: "Dermatología")
    FactoryBot.create(:study, topic: "Oncología")

    get root_path

    expect(response.body).to include("Todos los estudios")
    expect(response.body).to include("Dermatología")
    expect(response.body).to include("Oncología")
  end

  it "filters the showcase when a topic pill is followed" do
    derm = FactoryBot.create(:study, topic: "Dermatología")
    onco = FactoryBot.create(:study, topic: "Oncología")

    get root_path(topic: "Dermatología")

    expect(response).to be_successful
    expect(response.body).to include(derm.public_title)
    expect(response.body).not_to include(onco.public_title)
  end

  it "keeps topicless studies visible in the unfiltered showcase, without a pill" do
    bare = FactoryBot.create(:study, topic: nil)

    get root_path

    expect(response.body).to include(bare.public_title)
  end

  it "shows an empty state instead of erroring on an unknown topic" do
    FactoryBot.create(:study, topic: "Dermatología")

    get root_path(topic: "No existe")

    expect(response).to be_successful
    expect(response.body).to include("Por ahora no hay estudios en este tema.")
  end
end
