require "test_helper"

class IrRemoteTest < ActiveSupport::TestCase
  test "loads the learned sceptre and soundbar catalogs" do
    ids = IrRemote.all.map(&:id)
    assert_includes ids, "sceptre"
    assert_includes ids, "soundbar"
  end

  test "sceptre power is sony address 1 command 21" do
    remote = IrRemote.find("sceptre")
    payload = remote.payload_for("power")
    assert_equal "sony", payload["protocol"]
    assert_equal 1, payload["address"]
    assert_equal 21, payload["command"]
    assert_equal 40000, payload["freq"]
    assert_equal 5, payload["repeat"]
    assert_equal 12, payload["bits"]
  end

  test "soundbar mute is nec extended address" do
    remote = IrRemote.find("soundbar")
    payload = remote.payload_for("mute")
    assert_equal "nec", payload["protocol"]
    assert_equal 46723, payload["address"]
    assert_equal 67, payload["command"]
    assert_equal 38000, payload["freq"]
  end

  test "unknown remote or button is nil" do
    assert_nil IrRemote.find("missing")
    assert_nil IrRemote.find("sceptre").payload_for("nope")
  end

  test "layout expands buttons and spacers" do
    row = IrRemote.find("soundbar").rows[3]
    assert_equal :spacer, row[0]
    assert_equal "play", row[1][:id]
    assert_equal :spacer, row[2]
  end
end
