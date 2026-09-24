require "test_helper"

class PlayerControllerTest < ActionDispatch::IntegrationTest
  teardown do
    Playback.factory = nil
    AudioQueue.factory = nil
    VideoQueue.factory = nil
  end

  test "play starts playback and returns to root" do
    Playback.factory = -> { fake_playback(play: true) }
    post play_url
    assert_redirected_to root_url
  end

  test "play failure shows an alert" do
    Playback.factory = -> { fake_playback(play: false) }
    post play_url
    follow_redirect!
    assert_match "Could not start playback.", response.body
  end

  test "stop stops playback and returns to root" do
    Playback.factory = -> { fake_playback(stop: true) }
    post stop_url
    assert_redirected_to root_url
  end

  test "stop failure shows an alert" do
    Playback.factory = -> { fake_playback(stop: false) }
    post stop_url
    follow_redirect!
    assert_match "Could not pause playback.", response.body
  end

  test "play_item plays an album and stays on that tab" do
    played = nil
    playback = fake_playback
    playback.define_singleton_method(:play_audio_album) { |name, track: nil| played = [ name, track ]; true }
    Playback.factory = -> { playback }

    post play_item_url, params: { album: "calming_guitar" }

    assert_equal [ "calming_guitar", nil ], played
    assert_redirected_to library_url(media: "audio", album: "calming_guitar")
  end

  test "play_item plays a single track" do
    played = nil
    playback = fake_playback
    playback.define_singleton_method(:play_audio_album) { |name, track: nil| played = [ name, track ]; true }
    Playback.factory = -> { playback }
    track = "/mnt/audio_cds/calming_guitar/bittersweet.wav"

    post play_item_url, params: { album: "calming_guitar", track: track }

    assert_equal [ "calming_guitar", track ], played
    assert_redirected_to library_url(media: "audio", album: "calming_guitar")
  end

  test "play_item failure shows an alert" do
    playback = fake_playback
    playback.define_singleton_method(:play_audio_album) { |*_args, **_kwargs| false }
    Playback.factory = -> { playback }

    post play_item_url, params: { album: "missing" }
    follow_redirect!
    assert_match "Could not play that selection.", response.body
  end

  test "play_video plays a file and stays on the video tab" do
    played = nil
    playback = fake_playback
    playback.define_singleton_method(:play_video) { |path| played = path; true }
    Playback.factory = -> { playback }
    path = "/mnt/movies/the_legend_of_johnny_lingo.avi"

    post play_video_url, params: { collection: "movies", path: path }

    assert_equal path, played
    assert_redirected_to library_url(media: "video", collection: "movies")
  end

  test "seek updates playback and returns json" do
    seeked = nil
    playback = fake_playback
    playback.define_singleton_method(:seek) { |percent| seeked = percent; true }
    playback.define_singleton_method(:now_playing) { { state: "playing", percent: 40 } }
    Playback.factory = -> { playback }

    post seek_url, params: { percent: 40 }, as: :json

    assert_response :success
    assert_equal 40, seeked
    assert_equal 40, JSON.parse(response.body)["percent"]
  end

  test "replay skips backward and returns json" do
    replayed = nil
    playback = fake_playback
    playback.define_singleton_method(:replay) { |seconds| replayed = seconds; true }
    playback.define_singleton_method(:now_playing) { { state: "playing", percent: 8 } }
    Playback.factory = -> { playback }

    post replay_url, params: { seconds: 30 }, as: :json

    assert_response :success
    assert_equal 30, replayed
  end

  test "forward skips ahead and returns json" do
    forwarded = nil
    playback = fake_playback
    playback.define_singleton_method(:forward) { |seconds| forwarded = seconds; true }
    playback.define_singleton_method(:now_playing) { { state: "playing", percent: 20 } }
    Playback.factory = -> { playback }

    post forward_url, params: { seconds: 30 }, as: :json

    assert_response :success
    assert_equal 30, forwarded
  end

  test "now playing returns json" do
    playback = fake_playback
    playback.define_singleton_method(:now_playing) do
      { state: "playing", kind: "audio", title: "Bittersweet", percent: 50 }
    end
    Playback.factory = -> { playback }

    get now_playing_url, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "playing", body["state"]
    assert_equal "Bittersweet", body["title"]
    assert_equal "audio", body["kind"]
  end

  private

  def fake_playback(play: true, stop: true)
    playback = Object.new
    playback.define_singleton_method(:play) { play }
    playback.define_singleton_method(:stop) { stop }
    playback.define_singleton_method(:now_playing) { { state: "stopped", kind: "audio" } }
    playback
  end
end
