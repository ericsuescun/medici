require "application_system_test_case"

class TrialCenterFacilitiesTest < ApplicationSystemTestCase
  setup do
    @trial_center_facility = trial_center_facilities(:one)
  end

  test "visiting the index" do
    visit trial_center_facilities_url
    assert_selector "h1", text: "Trial center facilities"
  end

  test "should create trial center facility" do
    visit trial_center_facilities_url
    click_on "New trial center facility"

    fill_in "Contact address", with: @trial_center_facility.contact_address
    fill_in "Contact number", with: @trial_center_facility.contact_number
    fill_in "Description", with: @trial_center_facility.description
    fill_in "Email", with: @trial_center_facility.email
    fill_in "Initials", with: @trial_center_facility.initials
    fill_in "Name", with: @trial_center_facility.name
    fill_in "Url", with: @trial_center_facility.url
    click_on "Create Trial center facility"

    assert_text "Trial center facility was successfully created"
    click_on "Back"
  end

  test "should update Trial center facility" do
    visit trial_center_facility_url(@trial_center_facility)
    click_on "Edit this trial center facility", match: :first

    fill_in "Contact address", with: @trial_center_facility.contact_address
    fill_in "Contact number", with: @trial_center_facility.contact_number
    fill_in "Description", with: @trial_center_facility.description
    fill_in "Email", with: @trial_center_facility.email
    fill_in "Initials", with: @trial_center_facility.initials
    fill_in "Name", with: @trial_center_facility.name
    fill_in "Url", with: @trial_center_facility.url
    click_on "Update Trial center facility"

    assert_text "Trial center facility was successfully updated"
    click_on "Back"
  end

  test "should destroy Trial center facility" do
    visit trial_center_facility_url(@trial_center_facility)
    click_on "Destroy this trial center facility", match: :first

    assert_text "Trial center facility was successfully destroyed"
  end
end
