require 'rails_helper'

RSpec.describe "trial_center_branches/index", type: :view do
  before(:each) do
    assign(:trial_center_branches, [
      TrialCenterBranch.create!(
        name: "Name",
        initials: "Initials",
        description: "Description",
        trial_center_facility: nil
      ),
      TrialCenterBranch.create!(
        name: "Name",
        initials: "Initials",
        description: "Description",
        trial_center_facility: nil
      )
    ])
  end

  it "renders a list of trial_center_branches" do
    render
    cell_selector = 'div>p'
    assert_select cell_selector, text: Regexp.new("Name".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Initials".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Description".to_s), count: 2
    assert_select cell_selector, text: Regexp.new(nil.to_s), count: 2
  end
end
