require 'rails_helper'

RSpec.describe "trial_center_branches/show", type: :view do
  before(:each) do
    # The view calls policy(...) for the rep actions; stub it permissively since
    # this spec only checks that attributes render. (Pundit's `policy` helper is
    # mixed in at render time, so bypass partial-double verification.)
    without_partial_double_verification do
      allow(view).to receive(:policy)
        .and_return(double(new?: true, edit?: true, destroy?: true, show?: true, update?: true))
    end

    assign(:trial_center_branch, TrialCenterBranch.create!(
      name: "Name",
      initials: "Initials",
      description: "Description",
      trial_center_facility: FactoryBot.create(:trial_center_facility)
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
