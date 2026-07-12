require 'rails_helper'

RSpec.describe "trial_center_branches/index", type: :view do
  before(:each) do
    assign(:trial_center_branches, [
      TrialCenterBranch.create!(
        name: "Name",
        initials: "Initials",
        description: "Description",
        trial_center_facility: FactoryBot.create(:trial_center_facility)
      ),
      TrialCenterBranch.create!(
        name: "Name",
        initials: "Initials",
        description: "Description",
        trial_center_facility: FactoryBot.create(:trial_center_facility)
      )
    ])
  end

  it "renders a list of trial_center_branches" do
    render
    assert_select ".branch-card", count: 2
    assert_select "h5.card-header", text: "Name", count: 2
    assert_select "h5.card-title", text: "Description", count: 2
  end
end
