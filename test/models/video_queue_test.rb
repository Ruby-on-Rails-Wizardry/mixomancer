require "test_helper"

class VideoQueueTest < ActiveSupport::TestCase
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
      when "start", "restart"
        @active = true
        true
      when "stop"
        @active = false
        true
      end
    end
  end

  setup do
    @tmpdir = Pathname.new(Dir.mktmpdir("mixomancer-video"))
    @movies = @tmpdir.join("movies")
    @shows = @tmpdir.join("shows")
    @movies.mkpath
    @shows.mkpath
    @current = @tmpdir.join("video-current")
    @mpv = FakeMpv.new
    @runner = FakeRunner.new
    @queue = VideoQueue.new(
      mpv: @mpv,
      runner: @runner,
      current_path: @current,
      roots: [ @movies, @shows ],
      pid_reader: -> { 0 },
      journal_reader: -> { "" }
    )
  end

  teardown do
    FileUtils.remove_entry(@tmpdir)
  end

  test "play_path writes the current file and starts the unit when stopped" do
    file = @movies.join("the_legend_of_johnny_lingo.avi")
    FileUtils.touch(file)
    assert @queue.play_path(file.to_s)
    assert_equal file.realpath.to_s, @current.read.strip
    assert_includes @runner.calls, [ "start", VideoQueue::UNIT ]
  end

  test "play_path replaces the file in the running player" do
    @runner.active = true
    file = @movies.join("episode.m4v")
    FileUtils.touch(file)
    assert @queue.play_path(file.to_s)
    assert_equal [ "loadfile", file.realpath.to_s, "replace" ], @mpv.commands[0]
    assert_equal [ [ "pause", false ] ], @mpv.sets
    refute_includes @runner.calls.map(&:first), "restart"
    refute_includes @runner.calls.map(&:first), "start"
  end

  test "play_path rejects files outside the video library" do
    outside = @tmpdir.join("evil.avi")
    FileUtils.touch(outside)
    refute @queue.play_path(outside.to_s)
    refute @current.exist?
  end

  test "stop pauses mpv and keeps the unit running" do
    @runner.active = true
    @mpv.props.merge!("pause" => false, "path" => "/mnt/movies/the_legend_of_johnny_lingo.avi", "time-pos" => 90, "duration" => 180)
    assert @queue.stop
    assert_equal [ [ "pause", true ] ], @mpv.sets
    refute_includes @runner.calls.map(&:first), "stop"
    assert @runner.active
  end

  test "seek jumps to a percent of the video" do
    @runner.active = true
    @mpv.props.merge!("pause" => false, "path" => "/mnt/movies/the_legend_of_johnny_lingo.avi", "time-pos" => 10, "duration" => 200)
    assert @queue.seek(25)
    assert_includes @mpv.commands, [ "seek", 50.0, "absolute" ]
  end

  test "quit stops the unit" do
    @runner.active = true
    assert @queue.quit
    assert_includes @runner.calls, [ "stop", VideoQueue::UNIT ]
  end

  test "now playing reads mpv when the unit is active" do
    @runner.active = true
    @mpv.props.merge!(
      "path" => "/mnt/movies/the_legend_of_johnny_lingo.avi",
      "pause" => false,
      "time-pos" => 90,
      "duration" => 180
    )
    status = @queue.now_playing
    assert_equal "playing", status[:state]
    assert_equal "The Legend Of Johnny Lingo", status[:title]
    assert_equal "1:30", status[:position_label]
  end

  test "now playing falls back to cmdline and journal when IPC is empty" do
    file = @movies.join("the_legend_of_johnny_lingo.avi")
    FileUtils.touch(file)
    @runner.active = true
    queue = VideoQueue.new(
      mpv: @mpv,
      runner: @runner,
      current_path: @current,
      roots: [ @movies, @shows ],
      pid_reader: -> { 4242 },
      journal_reader: -> { "AV: 00:27:37 / 01:31:19 (30%) A-V: 0.000 Cache: 941s/150MB\n" }
    )
    queue.define_singleton_method(:path_from_cmdline) { file.to_s }

    status = queue.now_playing
    assert_equal "playing", status[:state]
    assert_equal "The Legend Of Johnny Lingo", status[:title]
    assert_equal "27:37", status[:position_label]
    assert_equal "1:31:19", status[:duration_label]
    assert_equal 30, status[:percent]
  end
end
