require 'rails_helper'

# The study page's "Sujetos interesados" counter and patient table read
# patients.study_id — the old studies_users join went permanently empty when
# patient accounts were removed, so both showed 0/nothing for months.
RSpec.describe "Study page patient data", type: :request do
  let(:branch) { FactoryBot.create(:trial_center_branch) }
  let(:study) { FactoryBot.create(:study).tap { |s| s.trial_center_branches << branch } }
  let!(:patient) { FactoryBot.create(:patient, :participant, study: study, firstname: "Zoraida") }

  it "shows admins the real pipeline count and the patient list" do
    sign_in(FactoryBot.create(:user, :admin), scope: :user)

    get study_path(study)

    expect(response).to be_successful
    expect(response.body).to include("#{I18n.t("studies.interested_subjects")}:</strong> 1")
    expect(response.body).to include("Zoraida")
  end

  it "narrows the list to the rep's reach while keeping the aggregate count" do
    other_branch = FactoryBot.create(:trial_center_branch)
    rep = FactoryBot.create(:trial_center_branch_rep, trial_center_branch: other_branch)
    sign_in(FactoryBot.create(:user, userable: rep), scope: :user)

    get study_path(study)

    expect(response).to be_successful
    # The aggregate stays (it discloses no identity)…
    expect(response.body).to include("#{I18n.t("studies.interested_subjects")}:</strong> 1")
    # …but an out-of-reach rep gets no patient rows.
    expect(response.body).not_to include("Zoraida")
  end
end
