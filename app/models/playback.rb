# Website-facing audio + video control. HDMI follows the selection.
class Playback
  class << self
    attr_accessor :factory

    def build(...)
      factory ? factory.call(...) : new(...)
    end
  end

  def initialize(audio: nil, video: nil, display: HdmiDisplay)
    @audio = audio || AudioQueue.build
    @video = video || VideoQueue.build
    @display = display
  end

  def now_playing
    video = @video.now_playing
    status = if video[:state] != "stopped"
      video.merge(kind: "video")
    else
      @audio.now_playing.merge(kind: "audio")
    end
    status.merge(artwork_url: Artwork.url_for(title: status[:title], album: status[:album]))
  end

  def play
    video = @video.now_playing
    if video[:state] == "paused"
      return @video.play
    end
    if video[:state] == "playing"
      return true
    end

    @display.ensure_kiosk
    @audio.play
  end

  def stop
    video = @video.now_playing
    return @video.stop if video[:state] != "stopped"

    @audio.stop
  end

  def play_audio_paths(paths)
    @video.quit
    @display.ensure_kiosk
    @audio.play_paths(paths)
  end

  def play_audio_album(name, track: nil)
    paths = track.present? ? [ track ] : @audio.album_paths(name)
    play_audio_paths(paths)
  end

  def play_video(path)
    @audio.stop
    @video.play_path(path)
  end

  def seek(percent)
    video = @video.now_playing
    return @video.seek(percent) if video[:state] != "stopped"

    @audio.seek(percent)
  end

  def replay(seconds = 30)
    video = @video.now_playing
    return @video.replay(seconds) if video[:state] != "stopped"

    @audio.replay(seconds)
  end
end
