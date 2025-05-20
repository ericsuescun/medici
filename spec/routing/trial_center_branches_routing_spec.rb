require "rails_helper"

RSpec.describe TrialCenterBranchesController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/trial_center_branches").to route_to("trial_center_branches#index")
    end

    it "routes to #new" do
      expect(get: "/trial_center_branches/new").to route_to("trial_center_branches#new")
    end

    it "routes to #show" do
      expect(get: "/trial_center_branches/1").to route_to("trial_center_branches#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/trial_center_branches/1/edit").to route_to("trial_center_branches#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/trial_center_branches").to route_to("trial_center_branches#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/trial_center_branches/1").to route_to("trial_center_branches#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/trial_center_branches/1").to route_to("trial_center_branches#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/trial_center_branches/1").to route_to("trial_center_branches#destroy", id: "1")
    end
  end
end
