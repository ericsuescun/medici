require "test_helper"

class TrialCitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @trial_city = trial_cities(:one)
  end

  test "should get index" do
    get trial_cities_url
    assert_response :success
  end

  test "should get new" do
    get new_trial_city_url
    assert_response :success
  end

  test "should create trial_city" do
    assert_difference("TrialCity.count") do
      post trial_cities_url, params: { trial_city: { name: @trial_city.name, studies_id: @trial_city.studies_id } }
    end

    assert_redirected_to trial_city_url(TrialCity.last)
  end

  test "should show trial_city" do
    get trial_city_url(@trial_city)
    assert_response :success
  end

  test "should get edit" do
    get edit_trial_city_url(@trial_city)
    assert_response :success
  end

  test "should update trial_city" do
    patch trial_city_url(@trial_city), params: { trial_city: { name: @trial_city.name, studies_id: @trial_city.studies_id } }
    assert_redirected_to trial_city_url(@trial_city)
  end

  test "should destroy trial_city" do
    assert_difference("TrialCity.count", -1) do
      delete trial_city_url(@trial_city)
    end

    assert_redirected_to trial_cities_url
  end
end
