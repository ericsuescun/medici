require 'rails_helper'

RSpec.describe "Search", type: :request do
  let(:branch_a) { FactoryBot.create(:trial_center_branch) }
  let(:branch_b) { FactoryBot.create(:trial_center_branch) }
  let!(:study_a) { FactoryBot.create(:study, public_title: "Cardio Alpha").tap { |s| s.trial_center_branches << branch_a } }
  let!(:study_b) { FactoryBot.create(:study, public_title: "Cardio Beta").tap { |s| s.trial_center_branches << branch_b } }

  it "requires authentication" do
    get search_path(q: "Cardio")
    expect(response).to redirect_to(new_user_session_path)
  end

  describe "as an admin" do
    before { sign_in FactoryBot.create(:user, :admin) }

    it "shows results grouped by type" do
      get search_path(q: "Cardio")
      expect(response).to be_successful
      expect(response.body).to include("Cardio Alpha")
      expect(response.body).to include("Cardio Beta")
      expect(response.body).to include(I18n.t("search.types.studies"))
    end

    it "shows a prompt for a blank query" do
      get search_path(q: "")
      expect(response).to be_successful
      expect(response.body).to include(I18n.t("search.prompt"))
    end

    it "reports no results for a non-matching query" do
      get search_path(q: "zzz-nothing-zzz")
      expect(response.body).to include(I18n.t("search.no_results", query: "zzz-nothing-zzz"))
    end
  end

  describe "as a trial centre rep on branch A" do
    before do
      rep = FactoryBot.create(:user, userable: FactoryBot.create(:trial_center_branch_rep, trial_center_branch: branch_a))
      sign_in rep
    end

    it "sees its own branch's study but not another branch's" do
      get search_path(q: "Cardio")
      expect(response.body).to include("Cardio Alpha")
      expect(response.body).not_to include("Cardio Beta")
    end
  end
end
