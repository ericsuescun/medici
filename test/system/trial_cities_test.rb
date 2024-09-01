require "application_system_test_case"

class TrialCitiesTest < ApplicationSystemTestCase
  setup do
    @trial_city = trial_cities(:one)
  end

  test "visiting the index" do
    visit trial_cities_url
    assert_selector "h1", text: "Trial cities"
  end

  test "should create trial city" do
    visit trial_cities_url
    click_on "New trial city"

    fill_in "Name", with: @trial_city.name
    fill_in "Studies", with: @trial_city.studies_id
    click_on "Create Trial city"

    assert_text "Trial city was successfully created"
    click_on "Back"
  end

  test "should update Trial city" do
    visit trial_city_url(@trial_city)
    click_on "Edit this trial city", match: :first

    fill_in "Name", with: @trial_city.name
    fill_in "Studies", with: @trial_city.studies_id
    click_on "Update Trial city"

    assert_text "Trial city was successfully updated"
    click_on "Back"
  end

  test "should destroy Trial city" do
    visit trial_city_url(@trial_city)
    click_on "Destroy this trial city", match: :first

    assert_text "Trial city was successfully destroyed"
  end
end
