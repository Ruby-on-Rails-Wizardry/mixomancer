class PlayerController < ApplicationController
  def play
    if Playback.build.play
      redirect_back_or_to root_path, status: :see_other
    else
      redirect_back_or_to root_path, alert: "Could not start playback.", status: :see_other
    end
  end

  def stop
    if Playback.build.stop
      redirect_back_or_to root_path, status: :see_other
    else
      redirect_back_or_to root_path, alert: "Could not stop playback.", status: :see_other
    end
  end

  def play_item
    album = params[:album].to_s
    if Playback.build.play_audio_album(album, track: params[:track])
      redirect_to library_path(media: "audio", album: album.presence), status: :see_other
    else
      redirect_to library_path(media: "audio", album: album.presence), alert: "Could not play that selection.", status: :see_other
    end
  end

  def play_video
    collection = params[:collection].to_s
    if Playback.build.play_video(params[:path])
      redirect_to library_path(media: "video", collection: collection.presence), status: :see_other
    else
      redirect_to library_path(media: "video", collection: collection.presence), alert: "Could not play that video.", status: :see_other
    end
  end

  def now_playing
    expires_now
    render json: Playback.build.now_playing
  end

  def seek
    percent = params[:percent].to_f
    if Playback.build.seek(percent)
      expires_now
      render json: Playback.build.now_playing
    else
      head :unprocessable_entity
    end
  end

  def replay
    seconds = (params[:seconds].presence || 30).to_f
    if Playback.build.replay(seconds)
      expires_now
      render json: Playback.build.now_playing
    else
      head :unprocessable_entity
    end
  end
end
