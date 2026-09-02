# HDMI movie/show player: systemd unit + mpv IPC.
class VideoQueue
  UNIT = "mixomancer-video.service"
  MOVIES = Pathname.new("/mnt/movies")
  SHOWS = Pathname.new("/mnt/shows")
  CURRENT_PATH = Pathname.new("/home/rob/audio-cds-queue/video-current")
  SOCKET = File.join(ENV.fetch("XDG_RUNTIME_DIR", "/run/user/1000"), "mpv-video.sock")
  VIDEO_EXTS = %w[.mp4 .mkv .m4v .avi .mov .webm .mpg .mpeg].freeze

  class << self
    attr_accessor :factory

    def build(...)
      factory ? factory.call(...) : new(...)
    end

    def humanize_name(text)
      AudioQueue.humanize_name(text)
    end

    def library_collections
      collections = []
      collections << collection_from("movies", "Movies", MOVIES) if MOVIES.directory?
      if SHOWS.directory?
        SHOWS.children.select(&:directory?).sort.each do |series|
          collections << collection_from(series.basename.to_s, humanize_name(series.basename.to_s), series)
        end
      end
      collections
    end

    def collection_from(name, label, dir)
      {
        name: name,
        label: label,
        path: dir.to_s,
        items: video_files(dir).map do |file|
          {
            filename: file.basename.to_s,
            path: file.to_s,
            title: humanize_name(file.basename.to_s)
          }
        end
      }
    end

    def video_files(dir)
      dir.glob("**/*").select { |path| path.file? && VIDEO_EXTS.include?(path.extname.downcase) }.sort
    end
  end

  JOURNAL_PROGRESS = /\bA(?:V)?:\s+(\d+:\d+(?::\d+)?)\s+\/\s+(\d+:\d+(?::\d+)?)/

  def initialize(mpv: MpvClient.new(path: SOCKET), runner: nil, current_path: CURRENT_PATH, roots: [ MOVIES, SHOWS ], pid_reader: nil, journal_reader: nil)
    @mpv = mpv
    @runner = runner || ->(*args) { HdmiDisplay.systemctl(*args) }
    @current_path = Pathname.new(current_path)
    @roots = Array(roots).map { |root| Pathname.new(root) }
    @pid_reader = pid_reader || -> { `systemctl show -p MainPID --value #{UNIT} 2>/dev/null`.to_i }
    @journal_reader = journal_reader || -> { `journalctl -u #{UNIT} -n 40 -o cat --no-pager 2>/dev/null` }
  end

  def now_playing
    return stopped_status unless unit_active?

    props = @mpv.properties("path", "pause", "time-pos", "duration")
    path = props["path"].presence || fallback_path
    position = props["time-pos"]
    duration = props["duration"]
    if position.nil? || duration.nil?
      journal_position, journal_duration = progress_from_journal
      position ||= journal_position
      duration ||= journal_duration
    end
    paused = props["pause"] == true || process_stopped?

    {
      state: paused ? "paused" : "playing",
      path: path,
      album: album_from(path),
      title: title_from(path),
      position: position,
      duration: duration,
      position_label: format_time(position),
      duration_label: format_time(duration),
      percent: percent(position, duration),
      playlist_pos: 1,
      playlist_count: 1
    }
  rescue StandardError
    unit_active? ? playing_without_track : stopped_status
  end

  def play_path(path)
    file = sanitize_path(path)
    return false unless file

    @current_path.dirname.mkpath
    @current_path.write("#{file}\n")

    if unit_active?
      return true if replace_file(file)
      return @runner.call("restart", UNIT)
    end

    @runner.call("start", UNIT)
  end

  def play
    status = now_playing
    if status[:state] == "paused"
      return true if @mpv.set_property("pause", false)
      return thaw_process
    end
    return true if status[:state] == "playing"

    false
  end

  def stop
    status = now_playing
    return true if status[:state] == "stopped" || status[:state] == "paused"
    return true if @mpv.set_property("pause", true)

    freeze_process
  end

  def quit
    return true unless unit_active?

    @runner.call("stop", UNIT)
  end

  def seek(percent)
    status = now_playing
    return false if status[:state] == "stopped"

    duration = status[:duration].to_f
    return false if duration <= 0

    seconds = (percent.to_f.clamp(0, 100) / 100.0) * duration
    @mpv.command([ "seek", seconds, "absolute" ])
  end

  def replay(seconds = 30)
    skip(-seconds.to_f)
  end

  def forward(seconds = 30)
    skip(seconds.to_f)
  end

  private

  def skip(seconds)
    status = now_playing
    return false if status[:state] == "stopped"

    @mpv.command([ "seek", seconds.to_f, "relative" ])
  end

  def unit_active?
    @runner.call("is-active", "--quiet", UNIT)
  end

  def replace_file(file)
    return false unless @mpv.command([ "loadfile", file, "replace" ])

    @mpv.set_property("pause", false)
    true
  end

  def sanitize_path(raw)
    path = Pathname.new(raw)
    return unless path.exist? && path.file?

    real = path.realpath.to_s
    return unless @roots.any? { |root| root.exist? && real.start_with?(root.realpath.to_s + File::SEPARATOR) }
    return unless VIDEO_EXTS.include?(File.extname(real).downcase)

    real
  end

  def stopped_status
    {
      state: "stopped",
      path: nil,
      album: nil,
      title: nil,
      position: nil,
      duration: nil,
      position_label: "0:00",
      duration_label: "0:00",
      percent: 0,
      playlist_pos: nil,
      playlist_count: 1
    }
  end

  def playing_without_track
    path = fallback_path
    position, duration = progress_from_journal
    stopped_status.merge(
      state: "playing",
      path: path,
      album: album_from(path),
      title: title_from(path),
      position: position,
      duration: duration,
      position_label: format_time(position),
      duration_label: format_time(duration),
      percent: percent(position, duration)
    )
  rescue StandardError
    stopped_status.merge(state: "playing")
  end

  def process_stopped?
    pid = @pid_reader.call.to_i
    return false if pid <= 0

    File.read("/proc/#{pid}/stat")[/\) (\S+)/, 1] == "T"
  rescue Errno::ENOENT
    false
  end

  def freeze_process
    signal_process("STOP")
  end

  def thaw_process
    signal_process("CONT")
  end

  def signal_process(name)
    pid = @pid_reader.call.to_i
    return false if pid <= 0

    Process.kill(name, pid)
    true
  rescue Errno::ESRCH
    false
  end

  def fallback_path
    if @current_path.file?
      stored = @current_path.read.strip
      return stored if stored.present?
    end
    path_from_cmdline
  end

  def path_from_cmdline
    pid = @pid_reader.call.to_i
    return if pid <= 0

    File.read("/proc/#{pid}/cmdline").split("\0").reverse.find do |arg|
      VIDEO_EXTS.include?(File.extname(arg).downcase)
    end
  rescue Errno::ENOENT
    nil
  end

  def progress_from_journal
    log = @journal_reader.call.to_s
    log.lines.reverse_each do |line|
      match = JOURNAL_PROGRESS.match(line)
      next unless match

      return [ parse_clock(match[1]), parse_clock(match[2]) ]
    end
    [ nil, nil ]
  end

  def parse_clock(stamp)
    parts = stamp.split(":").map(&:to_i)
    case parts.size
    when 3 then parts[0] * 3600 + parts[1] * 60 + parts[2]
    when 2 then parts[0] * 60 + parts[1]
    else parts.last
    end
  end

  def album_from(path)
    return if path.blank?

    pathname = Pathname.new(path)
    movies = self.class::MOVIES
    shows = self.class::SHOWS
    if movies.exist? && pathname.exist? && pathname.realpath.to_s.start_with?(movies.realpath.to_s + File::SEPARATOR)
      return "Movies"
    end
    if shows.exist? && pathname.exist? && pathname.realpath.to_s.start_with?(shows.realpath.to_s + File::SEPARATOR)
      series = pathname.realpath.relative_path_from(shows.realpath).each_filename.first
      return self.class.humanize_name(series)
    end

    self.class.humanize_name(pathname.dirname.basename.to_s)
  end

  def title_from(path)
    return if path.blank?

    self.class.humanize_name(Pathname.new(path).basename.to_s)
  end

  def format_time(seconds)
    return "0:00" if seconds.nil?

    total = seconds.to_i
    hours = total / 3600
    minutes = (total % 3600) / 60
    secs = total % 60
    if hours.positive?
      format("%d:%02d:%02d", hours, minutes, secs)
    else
      format("%d:%02d", minutes, secs)
    end
  end

  def percent(position, duration)
    return 0 if position.nil? || duration.nil? || duration.to_f <= 0

    ((position.to_f / duration.to_f) * 100).clamp(0, 100).round
  end
end
