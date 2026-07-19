require 'rails_helper'

# The study page's "Sujetos interesados" counter and patient table read
# patients.study_id — the old studies_users join went permanently empty when
# patient accounts were removed, so both showed 0/nothing for months.
RSpec.describe "Study page patient data", type: :request do
  let(:branch) { FactoryBot.create(:trial_center_branch) }
  let(:study) { FactoryBot.create(:study).tap { |s| s.trial_center_branches << branch } }
  let!(:patient) { FactoryBot.create(:patient, :participant, study: study, firstname: "Zoraida") }

  it "lists the criteria profile's variables in Demográfico with a quick-nav anchor" do
    profile = FactoryBot.create(:criteria_profile, study: study)
    FactoryBot.create(:criteria_variable, criteria_profile: profile, variable_type: "inclusion", name: "Edad entre 18 y 40")
    FactoryBot.create(:criteria_variable, criteria_profile: profile, variable_type: "exclusion", name: "Embarazo actual")
    sign_in(FactoryBot.create(:user, :admin), scope: :user)

    get study_path(study)

    expect(response.body).to include("Edad entre 18 y 40")
    expect(response.body).to include("Embarazo actual")
    expect(response.body).to include('href="#perfil-de-criterios"')
    expect(response.body).to include('id="perfil-de-criterios"')
  end

  it "shows admins the real pipeline count and the patient list" do
    sign_in(FactoryBot.create(:user, :admin), scope: :user)

    get study_path(study)

    expect(response).to be_successful
    expect(response.body).to include(I18n.t("studies.interested_subjects"))
    expect(response.body).to include('<span class="badge bg-primary">1</span>')
    expect(response.body).to include("Zoraida")
  end

  it "narrows the list to the rep's reach while keeping the aggregate count" do
    other_branch = FactoryBot.create(:trial_center_branch)
    rep = FactoryBot.create(:trial_center_branch_rep, trial_center_branch: other_branch)
    sign_in(FactoryBot.create(:user, userable: rep), scope: :user)

    get study_path(study)

    expect(response).to be_successful
    # The aggregate stays (it discloses no identity)…
    expect(response.body).to include('<span class="badge bg-primary">1</span>')
    # …but an out-of-reach rep gets no patient rows.
    expect(response.body).not_to include("Zoraida")
    expect(response.body).to include(I18n.t("studies.no_visible_patients"))
  end
end
