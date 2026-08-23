class HomeController < ApplicationController
  LIBRARY = Pathname.new("/mnt/audio_cds")
  QUEUE_UNIT = "audio-cds-queue.service"
  PLAYLIST = Pathname.new("/home/rob/audio-cds-queue/playlist.m3u")

  def index
    @library_root = LIBRARY
    @library_mounted = LIBRARY.directory?
    @albums = library_albums
    @queue_active = systemd_active?(QUEUE_UNIT)
    @playlist_tracks = playlist_tracks
  end

  private

  def library_albums
    return [] unless @library_mounted

    LIBRARY.children.select(&:directory?).sort.map do |dir|
      wavs = dir.glob("*.wav").sort
      { name: dir.basename.to_s, path: dir.to_s, tracks: wavs.map { |p| p.basename.to_s } }
    end
  end

  def playlist_tracks
    return [] unless PLAYLIST.file?

    PLAYLIST.readlines(chomp: true).filter_map do |line|
      next if line.blank? || line.start_with?("#")
      line
    end
  end

  def systemd_active?(unit)
    system("systemctl", "--user", "is-active", "--quiet", unit)
  end
end
