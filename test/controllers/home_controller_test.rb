require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @status = {
      state: "playing",
      kind: "audio",
      path: "/mnt/audio_cds/calming_guitar/bittersweet.wav",
      album: "Calming Guitar",
      title: "Bittersweet",
      position: 90,
      duration: 180,
      position_label: "1:30",
      duration_label: "3:00",
      percent: 50,
      playlist_pos: 3,
      playlist_count: 10
    }
    @playback = Object.new
    status = @status
    @playback.define_singleton_method(:now_playing) { status }
    Playback.factory = -> { @playback }
  end

  teardown do
    Playback.factory = nil
    AudioQueue.factory = nil
    VideoQueue.factory = nil
  end

  test "root renders mixomancer nav and now playing without the library" do
    get root_url
    assert_response :success
    assert_select "nav", text: /Ruby on Rails Wizardry/
    assert_select "nav a", text: "Mixomancer"
    assert_select "nav a", text: "Player"
    assert_select "nav a", text: "Library"
    assert_select "nav a", text: "Remotes"
    assert_select "nav a", text: "About"
    assert_select "h1", "Now playing"
    assert_select "[data-player-target=title]", "Bittersweet"
    assert_select "a", text: "Library"
    assert_select "form[action=?]", library_path, count: 0
    assert_no_match "Household DJ for Meadow Circle", @response.body
    assert_select "button", text: "Replay 30s"
    assert_select "button", text: "Forward 30s"
    assert_select "[role=tablist]", count: 0
    assert_select "[data-player-target=backdrop].is-on[style*=calming-guitar]"
  end

  test "root renders now playing and transport controls" do
    get root_url
    assert_select "form[action=?]", play_path
    assert_select "form[action=?]", stop_path
    assert_select "button[data-player-target=play][disabled]"
    assert_select "button[data-player-target=stop]:not([disabled])"
  end

  test "library page is linked from the nav" do
    get root_url
    assert_select "nav a[href=?]", library_path
  end

  test "library page links back to the player" do
    get library_url
    assert_select "nav a[href=?]", root_path, text: "Player"
  end

  test "library page renders audio tabs and play buttons" do
    get library_url
    assert_response :success
    assert_select "h1", "Library"
    assert_select "[role=tablist] a", minimum: 1
    assert_select "form[action=?]", play_item_path
    assert_select "button", text: "Play", minimum: 2
  end

  test "video library lists titles with play buttons" do
    get library_url, params: { media: "video" }
    assert_response :success
    assert_select "a", text: "Movies"
    assert_select "form[action=?]", play_video_path
  end

  test "display page is a kiosk now playing view with a control QR code" do
    get display_url
    assert_response :success
    assert_select "nav", count: 0
    assert_select "[data-player-target=title]", "Bittersweet"
    assert_match "Scan to control", @response.body
    assert_match "http://haruna.local:3000", @response.body
    assert_select "svg"
    assert_select "button", text: "Replay 30s", count: 0
    assert_select "button", text: "Forward 30s", count: 0
    assert_select "[data-player-target=backdrop]"
  end

  test "opera android can load the player" do
    get root_url, headers: {
      "User-Agent" => "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.6422.165 Mobile Safari/537.36 OPR/83.0.4254.73364"
    }
    assert_response :success
    assert_select "h1", "Now playing"
    assert_no_match "Your browser is not supported", @response.body
  end

  test "about page has the intro blurb" do
    get about_url
    assert_response :success
    assert_select "h1", "About"
    assert_match "Household DJ for Meadow Circle", @response.body
    assert_match "Mixomancer", @response.body
    assert_select "nav a", text: "About"
  end
end
