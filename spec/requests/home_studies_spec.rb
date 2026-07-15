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
end
