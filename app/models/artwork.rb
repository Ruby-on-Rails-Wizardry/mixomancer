# Cached 16:9 backgrounds keyed by album or title.
class Artwork
  DIR = Rails.root.join("public/artwork")
  GENERIC_TITLES = [ "track 1", "track 2", "track 3", "untitled" ].freeze

  def self.url_for(title: nil, album: nil)
    candidates = slugs_for(title: title, album: album)
    candidates.each do |slug|
      return "/artwork/#{slug}.jpg" if DIR.join("#{slug}.jpg").exist?
    end
    nil
  end

  def self.slugs_for(title: nil, album: nil)
    title = title.to_s.strip
    album = album.to_s.strip
    names = []
    names << album if album.present?
    names << title if title.present? && GENERIC_TITLES.exclude?(title.downcase)
    names.filter_map { |name| name.parameterize.presence }.uniq
  end
end
