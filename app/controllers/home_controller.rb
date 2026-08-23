class HomeController < ApplicationController
  def index
    @now_playing = Playback.build.now_playing
  end

  def library
    @now_playing = Playback.build.now_playing
    @media = if params[:media].present?
      params[:media] == "video" ? "video" : "audio"
    elsif @now_playing[:kind] == "video"
      "video"
    else
      "audio"
    end
    @albums = AudioQueue.library_albums
    @video_collections = VideoQueue.library_collections
    @selected_album = selected_album
    @selected_collection = selected_collection
    @library_root = AudioQueue::LIBRARY
    @library_mounted = AudioQueue::LIBRARY.directory?
  end

  def display
    @now_playing = Playback.build.now_playing
    @control_url = HdmiDisplay::CONTROL_URL
    render layout: "display"
  end

  def about
  end

  private

  def selected_album
    named = @albums.find { |album| album[:name] == params[:album] }
    return named if named

    if @now_playing[:kind] == "audio" && @now_playing[:path].present?
      current = Pathname.new(@now_playing[:path]).dirname.basename.to_s
      playing = @albums.find { |album| album[:name] == current }
      return playing if playing
    end

    @albums.first
  end

  def selected_collection
    named = @video_collections.find { |collection| collection[:name] == params[:collection] }
    return named if named

    if @now_playing[:kind] == "video" && @now_playing[:path].present?
      playing = @video_collections.find do |collection|
        collection[:items].any? { |item| item[:path] == @now_playing[:path] }
      end
      return playing if playing
    end

    @video_collections.first
  end
end
