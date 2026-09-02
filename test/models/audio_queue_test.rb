require "test_helper"

class AudioQueueTest < ActiveSupport::TestCase
  class FakeMpv
    attr_reader :props, :sets, :commands

    def initialize(props = {})
      @props = props
      @sets = []
      @commands = []
    end

    def properties(*names)
      names.index_with { |name| @props[name] }
    end

    def set_property(name, value)
      @sets << [ name, value ]
      @props[name] = value
      true
    end

    def command(args)
      @commands << args
      true
    end
  end

  class FakeRunner
    attr_accessor :active
    attr_reader :calls

    def initialize(active: false)
      @active = active
      @calls = []
    end

    def call(*args)
      @calls << args
      case args.first
      when "is-active" then @active
      when "start"
        @active = true
        true
      when "stop"
        @active = false
        true
      end
    end
  end

  setup do
    @tmpdir = Pathname.new(Dir.mktmpdir("mixomancer-queue"))
    @session = @tmpdir.join("session.m3u")
    @mpv = FakeMpv.new
    @runner = FakeRunner.new
    @queue = AudioQueue.new(mpv: @mpv, runner: @runner, session_playlist: @session, library: @tmpdir)
  end

  teardown do
    FileUtils.remove_entry(@tmpdir)
  end

  test "now playing is stopped when the unit is down" do
    status = @queue.now_playing
    assert_equal "stopped", status[:state]
    assert_nil status[:title]
    assert_equal 0, status[:percent]
  end

  test "now playing reads mpv when the unit is active" do
    @runner.active = true
    @mpv.props.merge!(
      "path" => "/mnt/audio_cds/calming_guitar/bittersweet.wav",
      "pause" => false,
      "time-pos" => 90.4,
      "duration" => 180,
      "playlist-pos" => 2,
      "playlist-count" => 10
    )

    status = @queue.now_playing
    assert_equal "playing", status[:state]
    assert_equal "Bittersweet", status[:title]
    assert_equal "Calming Guitar", status[:album]
    assert_equal "1:30", status[:position_label]
    assert_equal "3:00", status[:duration_label]
    assert_equal 50, status[:percent]
    assert_equal 3, status[:playlist_pos]
    assert_equal 10, status[:playlist_count]
  end

  test "now playing reports paused" do
    @runner.active = true
    @mpv.props["pause"] = true
    @mpv.props["path"] = "/mnt/audio_cds/calming_songbirds/Track 1.wav"

    status = @queue.now_playing
    assert_equal "paused", status[:state]
    assert_equal "Track 1", status[:title]
    assert_equal "Calming Songbirds", status[:album]
  end

  test "play starts the unit when stopped" do
    assert @queue.play
    assert_includes @runner.calls, [ "start", AudioQueue::UNIT ]
  end

  test "play is a no-op when already playing" do
    @runner.active = true
    @mpv.props["pause"] = false
    assert @queue.play
    refute_includes @runner.calls.map(&:first), "start"
  end

  test "seek jumps to a percent of the track" do
    @runner.active = true
    @mpv.props.merge!("pause" => false, "time-pos" => 10, "duration" => 200)
    assert @queue.seek(25)
    assert_equal [ [ "seek", 50.0, "absolute" ] ], @mpv.commands
  end

  test "replay seeks backward relatively" do
    @runner.active = true
    @mpv.props.merge!("pause" => false, "time-pos" => 90, "duration" => 200)
    assert @queue.replay(30)
    assert_equal [ [ "seek", -30.0, "relative" ] ], @mpv.commands
  end

  test "forward seeks ahead relatively" do
    @runner.active = true
    @mpv.props.merge!("pause" => false, "time-pos" => 90, "duration" => 200)
    assert @queue.forward(30)
    assert_equal [ [ "seek", 30.0, "relative" ] ], @mpv.commands
  end

  test "play unpauses when paused" do
    @runner.active = true
    @mpv.props["pause"] = true
    assert @queue.play
    assert_equal [ [ "pause", false ] ], @mpv.sets
    refute_includes @runner.calls.map(&:first), "start"
  end

  test "stop is a no-op when already stopped" do
    assert @queue.stop
    assert_empty @mpv.sets
    refute_includes @runner.calls.map(&:first), "stop"
  end

  test "stop pauses mpv and keeps the unit running" do
    @runner.active = true
    @mpv.props.merge!(
      "path" => "/mnt/audio_cds/calming_guitar/bittersweet.wav",
      "pause" => false,
      "time-pos" => 90.4,
      "duration" => 180
    )
    assert @queue.stop
    assert_equal [ [ "pause", true ] ], @mpv.sets
    refute_includes @runner.calls.map(&:first), "stop"
    assert @runner.active
    assert_equal "paused", @queue.now_playing[:state]
    assert_in_delta 90.4, @queue.now_playing[:position]
  end

  test "stop is a no-op when already paused" do
    @runner.active = true
    @mpv.props["pause"] = true
    assert @queue.stop
    assert_empty @mpv.sets
  end

  test "play resumes the same paused track" do
    @runner.active = true
    @mpv.props.merge!(
      "path" => "/mnt/audio_cds/calming_forest_sounds/Track 1.wav",
      "pause" => true,
      "time-pos" => 2224,
      "duration" => 3601
    )
    assert @queue.play
    assert_equal [ [ "pause", false ] ], @mpv.sets
    refute_includes @runner.calls.map(&:first), "start"
    @mpv.props["pause"] = false
    status = @queue.now_playing
    assert_equal "playing", status[:state]
    assert_equal "Track 1", status[:title]
    assert_equal "37:04", status[:position_label]
  end

  test "format long tracks with hours" do
    @runner.active = true
    @mpv.props.merge!("time-pos" => 2224, "duration" => 3601, "pause" => false)

    status = @queue.now_playing
    assert_equal "37:04", status[:position_label]
    assert_equal "1:00:01", status[:duration_label]
  end

  test "play removes a session playlist so the default mix starts" do
    @session.write("#EXTM3U\n/tmp/x.wav\n")
    assert @queue.play
    refute @session.exist?
    assert_includes @runner.calls, [ "start", AudioQueue::UNIT ]
  end

  test "play_paths starts the unit with a session playlist when stopped" do
    a, b = touch_library_wavs
    assert @queue.play_paths([ a.to_s, b.to_s ])
    assert_includes @runner.calls, [ "start", AudioQueue::UNIT ]
    contents = @session.read
    assert_match a.realpath.to_s, contents
    assert_match b.realpath.to_s, contents
    assert_empty @mpv.commands
  end

  test "play_paths replaces the running mpv playlist" do
    @runner.active = true
    a, b = touch_library_wavs
    assert @queue.play_paths([ a.to_s, b.to_s ])
    assert_equal [ "loadfile", a.realpath.to_s, "replace" ], @mpv.commands[0]
    assert_equal [ "loadfile", b.realpath.to_s, "append" ], @mpv.commands[1]
    assert_equal [ [ "pause", false ] ], @mpv.sets
    refute_includes @runner.calls.map(&:first), "start"
  end

  test "play_paths rejects files outside the library" do
    outside = Pathname.new(Dir.mktmpdir).join("evil.wav")
    FileUtils.touch(outside)
    refute @queue.play_paths([ outside.to_s ])
    refute @session.exist?
  ensure
    FileUtils.remove_entry(outside.dirname)
  end

  test "humanize_name titleizes ripped filenames" do
    assert_equal "Calming Guitar", AudioQueue.humanize_name("calming_guitar")
    assert_equal "A Step Closer", AudioQueue.humanize_name("a_step_closer.wav")
    assert_equal "Track 1", AudioQueue.humanize_name("Track 1.wav")
  end

  test "library albums follow playlist order" do
    names = AudioQueue.library_albums.map { |album| album[:name] }
    skip "library not mounted" if names.empty?
    assert_equal "calming_guitar", names.first
  end

  private

  def touch_library_wavs
    album = @tmpdir.join("calming_guitar")
    album.mkpath
    a = album.join("a_step_closer.wav")
    b = album.join("bittersweet.wav")
    FileUtils.touch(a)
    FileUtils.touch(b)
    [ a, b ]
  end
end
