require 'rails_helper'

RSpec.describe "trial_center_branches/new", type: :view do
  before(:each) do
    assign(:trial_center_branch, TrialCenterBranch.new(
      name: "MyString",
      initials: "MyString",
      description: "MyString",
      trial_center_facility: nil
    ))
  end

  it "renders new trial_center_branch form" do
    render

    assert_select "form[action=?][method=?]", trial_center_branches_path, "post" do

      assert_select "input[name=?]", "trial_center_branch[name]"

      assert_select "input[name=?]", "trial_center_branch[initials]"

      assert_select "input[name=?]", "trial_center_branch[description]"

      assert_select "input[name=?]", "trial_center_branch[trial_center_facility_id]"
    end
  end
end
