require "test_helper"

class PlaybackTest < ActiveSupport::TestCase
  class FakeMedia
    attr_accessor :status, :played_paths, :play_path_arg, :stopped, :played

    attr_accessor :seeked, :replayed, :forwarded

    def initialize(status = { state: "stopped" })
      @status = status
      @played_paths = nil
      @play_path_arg = nil
      @stopped = false
      @played = false
      @seeked = nil
      @replayed = nil
      @forwarded = nil
    end

    def now_playing
      @status
    end

    def play
      @played = true
      @status = @status.merge(state: "playing")
      true
    end

    def stop
      @stopped = true
      @status = { state: "stopped" }
      true
    end

    def play_paths(paths)
      @played_paths = paths
      @status = { state: "playing" }
      true
    end

    def album_paths(name)
      [ "/mnt/audio_cds/#{name}/a.wav" ]
    end

    def play_path(path)
      @play_path_arg = path
      @status = { state: "playing", path: path }
      true
    end

    def quit
      @stopped = true
      @status = { state: "stopped" }
      true
    end

    def seek(percent)
      @seeked = percent
      true
    end

    def replay(seconds)
      @replayed = seconds
      true
    end

    def forward(seconds)
      @forwarded = seconds
      true
    end
  end

  class FakeDisplay
    attr_reader :kiosk

    def initialize
      @kiosk = false
    end

    def ensure_kiosk
      @kiosk = true
    end
  end

  setup do
    @audio = FakeMedia.new
    @video = FakeMedia.new
    @display = FakeDisplay.new
    @playback = Playback.new(audio: @audio, video: @video, display: @display)
  end

  test "now playing prefers video when the HDMI player is up" do
    @video.status = { state: "playing", title: "Johnny Lingo" }
    @audio.status = { state: "paused", title: "Bittersweet" }
    status = @playback.now_playing
    assert_equal "video", status[:kind]
    assert_equal "Johnny Lingo", status[:title]
  end

  test "now playing falls back to audio" do
    @audio.status = { state: "playing", title: "Bittersweet" }
    status = @playback.now_playing
    assert_equal "audio", status[:kind]
    assert_equal "Bittersweet", status[:title]
  end

  test "play_audio_album quits video and shows the kiosk" do
    @video.status = { state: "playing" }
    assert @playback.play_audio_album("calming_guitar")
    assert @video.stopped
    assert @display.kiosk
    assert_equal [ "/mnt/audio_cds/calming_guitar/a.wav" ], @audio.played_paths
  end

  test "play_video pauses audio and starts the file" do
    @audio.status = { state: "playing" }
    path = "/mnt/movies/the_legend_of_johnny_lingo.avi"
    assert @playback.play_video(path)
    assert @audio.stopped
    assert_equal path, @video.play_path_arg
  end

  test "stop pauses video when video is playing" do
    @video.status = { state: "playing" }
    assert @playback.stop
    assert @video.stopped
    refute @audio.stopped
  end

  test "seek goes to video when a movie is up" do
    @video.status = { state: "playing" }
    assert @playback.seek(40)
    assert_equal 40, @video.seeked
    assert_nil @audio.seeked
  end

  test "forward goes to video when a movie is up" do
    @video.status = { state: "playing" }
    assert @playback.forward(30)
    assert_equal 30, @video.forwarded
    assert_nil @audio.forwarded
  end

  test "play resumes paused audio on the kiosk" do
    @audio.status = { state: "paused" }
    assert @playback.play
    assert @display.kiosk
    assert @audio.played
  end
end
