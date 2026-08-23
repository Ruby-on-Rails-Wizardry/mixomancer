# Shop music queue: systemd unit + mpv IPC on haruna.
class AudioQueue
  UNIT = "audio-cds-queue.service"
  PLAYLIST = Pathname.new("/home/rob/audio-cds-queue/playlist.m3u")
  SESSION_PLAYLIST = Pathname.new("/home/rob/audio-cds-queue/session.m3u")
  LIBRARY = Pathname.new("/mnt/audio_cds")

  class << self
    attr_accessor :factory

    def build(...)
      factory ? factory.call(...) : new(...)
    end

    def humanize_name(text)
      text.to_s.sub(/\.(wav|mp4|mkv|m4v|avi|mov|webm|mpg|mpeg)\z/i, "").tr("_", " ").titleize
    end

    def playlist_tracks
      return [] unless PLAYLIST.file?

      PLAYLIST.readlines(chomp: true).filter_map do |line|
        next if line.blank? || line.start_with?("#")
        line
      end
    end

    def playlist_album_order
      order = {}
      playlist_tracks.each do |track|
        name = Pathname.new(track).dirname.basename.to_s
        order[name] ||= order.size
      end
      order
    end

    def library_albums
      return [] unless LIBRARY.directory?

      album_order = playlist_album_order
      LIBRARY.children.select(&:directory?).sort_by do |dir|
        name = dir.basename.to_s
        [ album_order.fetch(name, 10_000), name ]
      end.map do |dir|
        wavs = dir.glob("*.wav").sort
        {
          name: dir.basename.to_s,
          label: humanize_name(dir.basename.to_s),
          path: dir.to_s,
          tracks: wavs.map do |wav|
            {
              filename: wav.basename.to_s,
              path: wav.to_s,
              title: humanize_name(wav.basename.to_s)
            }
          end
        }
      end
    end
  end

  def initialize(mpv: MpvClient.new, runner: nil, session_playlist: SESSION_PLAYLIST, library: LIBRARY)
    @mpv = mpv
    @runner = runner || ->(*args) { system("systemctl", "--user", *args) }
    @session_playlist = Pathname.new(session_playlist)
    @library = Pathname.new(library)
  end

  def now_playing
    return stopped_status unless unit_active?

    props = @mpv.properties("path", "pause", "time-pos", "duration", "playlist-pos", "playlist-count")
    path = props["path"]
    position = props["time-pos"]
    duration = props["duration"]
    paused = props["pause"] == true

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
      playlist_pos: props["playlist-pos"]&.+(1),
      playlist_count: props["playlist-count"] || self.class.playlist_tracks.size
    }
  rescue StandardError
    unit_active? ? playing_without_track : stopped_status
  end

  def play
    status = now_playing
    return @mpv.set_property("pause", false) if status[:state] == "paused"
    return true if status[:state] == "playing"

    @session_playlist.delete if @session_playlist.exist?
    start_unit
  end

  def play_paths(paths)
    files = sanitize_paths(paths)
    return false if files.empty?

    write_session_playlist(files)
    if unit_active?
      replace_playlist(files)
    else
      start_unit
    end
  end

  def album_paths(name)
    album = self.class.library_albums.find { |entry| entry[:name] == name }
    return [] unless album

    album[:tracks].map { |track| track[:path] }
  end

  def stop
    status = now_playing
    return true if status[:state] == "stopped" || status[:state] == "paused"

    @mpv.set_property("pause", true)
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
    status = now_playing
    return false if status[:state] == "stopped"

    @mpv.command([ "seek", -seconds.to_f, "relative" ])
  end

  private

  def unit_active?
    @runner.call("is-active", "--quiet", UNIT)
  end

  def start_unit
    @runner.call("start", UNIT)
  end

  def sanitize_paths(paths)
    return [] unless @library.exist?

    root = @library.realpath.to_s
    Array(paths).filter_map do |raw|
      path = Pathname.new(raw)
      next unless path.exist? && path.file?

      real = path.realpath.to_s
      next unless real.start_with?(root + File::SEPARATOR)
      next unless File.extname(real).casecmp(".wav").zero?

      real
    end
  end

  def write_session_playlist(files)
    @session_playlist.dirname.mkpath
    @session_playlist.write("#EXTM3U\n#{files.join("\n")}\n")
  end

  def replace_playlist(files)
    first, *rest = files
    ok = @mpv.command([ "loadfile", first, "replace" ])
    rest.each { |file| @mpv.command([ "loadfile", file, "append" ]) }
    @mpv.set_property("pause", false)
    ok
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
      playlist_count: self.class.playlist_tracks.size
    }
  end

  def playing_without_track
    stopped_status.merge(state: "playing")
  end

  def album_from(path)
    return if path.blank?

    self.class.humanize_name(Pathname.new(path).dirname.basename.to_s)
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
