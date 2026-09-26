require "test_helper"

class RemotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @sent = []
    blaster = Object.new
    sent = @sent
    blaster.define_singleton_method(:press) { |remote, command| sent << [ remote, command ]; true }
    blaster.define_singleton_method(:online?) { true }
    IrBlaster.factory = -> { blaster }
  end

  teardown do
    IrBlaster.factory = nil
  end

  test "index lists remotes" do
    get remotes_url
    assert_response :success
    assert_select "a", /Sceptre TV/
    assert_select "a", /Soundbar/
    assert_select "nav a", text: "Sceptre"
    assert_select "nav a", text: "Soundbar"
  end

  test "show renders the sceptre face" do
    get remote_url("sceptre")
    assert_response :success
    assert_select "title", text: "Sceptre TV · Mixomancer"
    assert_select "nav a[aria-current=page]", text: "Sceptre"
    assert_select "button[data-command=power]", text: "Power"
    assert_select "button[data-command=hdmi]", text: "HDMI"
    assert_select "button[data-command=vol_up][data-hold=true]"
  end

  test "show renders the soundbar face" do
    get remote_url("soundbar")
    assert_response :success
    assert_select "title", text: "Soundbar · Mixomancer"
    assert_select "nav a[aria-current=page]", text: "Soundbar"
    assert_select "button[data-command=music]", text: "MUSIC"
    assert_select "button[data-command=play]", text: "RESET"
  end

  test "unknown remote redirects" do
    get remote_url("nope")
    assert_redirected_to remotes_url
  end

  test "press blasts a named button" do
    post press_remote_url(id: "sceptre", command: "power"), as: :json
    assert_response :no_content
    assert_equal [ [ "sceptre", "power" ] ], @sent
  end

  test "press of an unknown button is 404" do
    post press_remote_url(id: "sceptre", command: "nope"), as: :json
    assert_response :not_found
    assert_empty @sent
  end

  test "press failure is 502 for json" do
    blaster = Object.new
    blaster.define_singleton_method(:press) { |*_args| false }
    IrBlaster.factory = -> { blaster }

    post press_remote_url(id: "soundbar", command: "mute"), as: :json
    assert_response :bad_gateway
  end
end
