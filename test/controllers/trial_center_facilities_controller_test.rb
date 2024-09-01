require "test_helper"

class TrialCenterFacilitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @trial_center_facility = trial_center_facilities(:one)
  end

  test "should get index" do
    get trial_center_facilities_url
    assert_response :success
  end

  test "should get new" do
    get new_trial_center_facility_url
    assert_response :success
  end

  test "should create trial_center_facility" do
    assert_difference("TrialCenterFacility.count") do
      post trial_center_facilities_url, params: { trial_center_facility: { contact_address: @trial_center_facility.contact_address, contact_number: @trial_center_facility.contact_number, description: @trial_center_facility.description, email: @trial_center_facility.email, initials: @trial_center_facility.initials, name: @trial_center_facility.name, url: @trial_center_facility.url } }
    end

    assert_redirected_to trial_center_facility_url(TrialCenterFacility.last)
  end

  test "should show trial_center_facility" do
    get trial_center_facility_url(@trial_center_facility)
    assert_response :success
  end

  test "should get edit" do
    get edit_trial_center_facility_url(@trial_center_facility)
    assert_response :success
  end

  test "should update trial_center_facility" do
    patch trial_center_facility_url(@trial_center_facility), params: { trial_center_facility: { contact_address: @trial_center_facility.contact_address, contact_number: @trial_center_facility.contact_number, description: @trial_center_facility.description, email: @trial_center_facility.email, initials: @trial_center_facility.initials, name: @trial_center_facility.name, url: @trial_center_facility.url } }
    assert_redirected_to trial_center_facility_url(@trial_center_facility)
  end

  test "should destroy trial_center_facility" do
    assert_difference("TrialCenterFacility.count", -1) do
      delete trial_center_facility_url(@trial_center_facility)
    end

    assert_redirected_to trial_center_facilities_url
  end
end
