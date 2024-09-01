require "test_helper"

class StaticPagesControllerTest < ActionDispatch::IntegrationTest
  test "should get medici_home" do
    get static_pages_medici_home_url
    assert_response :success
  end
end
