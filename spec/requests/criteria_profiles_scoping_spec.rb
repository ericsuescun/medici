require "rails_helper"

# End to end: the sponsor owns the criteria (2026-08-25), and one sponsor can
# never reach another's. The policy spec pins the Scope; these prove the
# controllers actually go through it — including the write paths, which are the
# ones that matter, because the criteria gate promotion.
RSpec.describe "Criteria profile scoping", type: :request do
  let(:sponsor_a) { FactoryBot.create(:sponsor) }
  let(:sponsor_b) { FactoryBot.create(:sponsor) }

  let(:study_a) { FactoryBot.create(:study, sponsor: sponsor_a) }
  let(:study_b) { FactoryBot.create(:study, sponsor: sponsor_b) }

  let(:admin) { FactoryBot.create(:user, :admin) }
  let!(:profile_a) { FactoryBot.create(:criteria_profile, study: study_a, user: admin) }
  let!(:profile_b) { FactoryBot.create(:criteria_profile, study: study_b, user: admin) }

  let(:rep_a) { FactoryBot.create(:user, userable: FactoryBot.create(:sponsor_rep, sponsor: sponsor_a)) }

  before { sign_in(rep_a, scope: :user) }

  it "reaches its own sponsor's profile, even though an admin created it" do
    get criteria_profile_path(profile_a)

    expect(response).to be_successful
  end

  # 404 rather than 403: a 403 confirms the record exists. `show_exceptions` is
  # :rescuable in the test env, so RecordNotFound arrives as a response, not a
  # raise — same convention as spec/requests/patient_page_spec.rb.
  it "404s on another sponsor's profile" do
    get criteria_profile_path(profile_b)

    expect(response).to have_http_status(:not_found)
  end

  it "cannot WRITE another sponsor's criteria — the gate patients are promoted through" do
    patch criteria_profile_path(profile_b), params: { criteria_profile: { name: "forged" } }

    expect(response).to have_http_status(:not_found)
    expect(profile_b.reload.name).not_to eq("forged")
  end

  it "cannot reach another sponsor's criteria variables" do
    get criteria_profile_criteria_variables_path(profile_b)

    expect(response).to have_http_status(:not_found)
  end

  it "cannot add a variable to another sponsor's profile" do
    post criteria_profile_criteria_variables_path(profile_b),
         params: { criteria_variable: { name: "forged", variable_type: "inclusion", value_type: "boolean", comparison_type: "true" } }

    expect(response).to have_http_status(:not_found)
    expect(profile_b.criteria_variables.where(name: "forged")).to be_empty
  end

  it "lists only its own sponsor's profiles on the index" do
    get criteria_profiles_path

    expect(response.body).to include(profile_a.name)
    expect(response.body).not_to include(profile_b.name)
  end
end
