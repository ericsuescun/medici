require 'rails_helper'

# The "ask online" switch on the criteria variable form exists for SPECIFIC
# rules only — a basic question is always asked online — so the form follows
# the category select as somebody changes it (specific_only_controller.js).
# The server-rendered initial state is pinned in
# spec/requests/centre_asked_questions_spec.rb; this covers the live toggle.
RSpec.feature "The ask-online switch follows the category", type: :feature, js: true do
  let(:admin) { create(:user, :admin) }
  let(:profile) { create(:criteria_profile) }

  before { login_as admin, scope: :user }

  scenario "appears when the rule becomes specific and hides again when it goes back to basic" do
    visit new_criteria_profile_criteria_variable_path(profile)
    label = I18n.t("criteria_variables.form.asked_online_label")
    category = CriteriaVariable.human_attribute_name(:criteria_category)

    expect(page).to have_no_field(label)

    select I18n.t("enums.criteria_variable.criteria_category.specific"), from: category
    expect(page).to have_field(label, checked: true)

    select I18n.t("enums.criteria_variable.criteria_category.basic"), from: category
    expect(page).to have_no_field(label)
  end
end
