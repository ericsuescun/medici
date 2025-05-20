require 'rails_helper'

RSpec.describe "trial_center_branches/show", type: :view do
  before(:each) do
    assign(:trial_center_branch, TrialCenterBranch.create!(
      name: "Name",
      initials: "Initials",
      description: "Description",
      trial_center_facility: nil
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Name/)
    expect(rendered).to match(/Initials/)
    expect(rendered).to match(/Description/)
    expect(rendered).to match(//)
  end
end
