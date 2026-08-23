require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "root renders mixomancer" do
    get root_url
    assert_response :success
    assert_select "h1", "Mixomancer"
  end
end
