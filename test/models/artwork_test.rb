require "test_helper"

class ArtworkTest < ActiveSupport::TestCase
  test "url_for uses album slug and skips generic titles" do
    assert_equal "/artwork/calming-forest-sounds.jpg",
      Artwork.url_for(title: "Track 1", album: "Calming Forest Sounds")
  end

  test "url_for returns nil when nothing is cached" do
    assert_nil Artwork.url_for(title: "Unknown Song", album: "Unknown Album")
  end
end
