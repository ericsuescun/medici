require 'rails_helper'

RSpec.describe "Cities", type: :request do
  let(:city) { FactoryBot.create(:city) }
  let(:branch_a) { FactoryBot.create(:trial_center_branch, name: "Sede Norte") }
  let(:branch_b) { FactoryBot.create(:trial_center_branch, name: "Sede Sur") }
  let!(:study_a) { FactoryBot.create(:study, public_title: "Estudio Alfa").tap { |s| s.trial_center_branches << branch_a } }
  let!(:study_b) { FactoryBot.create(:study, public_title: "Estudio Beta").tap { |s| s.trial_center_branches << branch_b } }

  before do
    branch_a.cities << city
    branch_b.cities << city
  end

  describe "as an admin" do
    before { sign_in(FactoryBot.create(:user, :admin), scope: :user) }

    it "lists cities in a striped table with every study running in each city" do
      get cities_path

      expect(response).to be_successful
      expect(response.body).to include("table-striped")
      expect(response.body).to include("Estudio Alfa")
      expect(response.body).to include("Estudio Beta")
    end

    it "details a city with all its branches and their studies" do
      get city_path(city)

      expect(response).to be_successful
      expect(response.body).to include("Sede Norte")
      expect(response.body).to include("Sede Sur")
      expect(response.body).to include("Estudio Alfa")
      expect(response.body).to include("Estudio Beta")
    end
  end

  describe "as a trial centre rep on branch A" do
    before do
      rep = FactoryBot.create(:trial_center_branch_rep, trial_center_branch: branch_a)
      sign_in(FactoryBot.create(:user, userable: rep), scope: :user)
    end

    it "sees only their branch's studies on the index" do
      get cities_path

      expect(response.body).to include("Estudio Alfa")
      expect(response.body).not_to include("Estudio Beta")
    end

    it "sees only their branch on the city detail" do
      get city_path(city)

      expect(response.body).to include("Sede Norte")
      expect(response.body).not_to include("Sede Sur")
      expect(response.body).not_to include("Estudio Beta")
    end
  end
end
