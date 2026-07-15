require 'rails_helper'

# The public "More about this study" info card must be reachable WITHOUT logging
# in (the authenticated StudiesController#show is behind Devise + Pundit).
RSpec.describe "Public study details", type: :request do
  it "is reachable by an anonymous visitor" do
    study = create(:study, public_title: "Vitalia Trial")
    get study_about_path(study)
    expect(response).to be_successful
    expect(response.body).to include("Vitalia Trial")
  end

  it "shows the enrollment status without exposing a count" do
    study = create(:study)
    study.users << create(:user, :patient)
    get study_about_path(study)
    expect(response).to be_successful
    # The card renders a yes/no badge, never the number of enrolled patients.
    expect(response.body).not_to match(/#{study.users.count}\s*patients?/i)
  end
end
