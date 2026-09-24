require "test_helper"

class KioskBrowserTest < ActiveSupport::TestCase
  class FakeDisplay
    attr_reader :restarts

    def initialize(ok: true)
      @ok = ok
      @restarts = 0
    end

    def restart_kiosk
      @restarts += 1
      @ok
    end
  end

  setup do
    @dir = Pathname.new(Dir.mktmpdir)
    @display = FakeDisplay.new
    @browser = KioskBrowser.new(path: @dir.join("kiosk-url"), display: @display)
  end

  teardown do
    FileUtils.remove_entry(@dir)
  end

  test "url is the display when nothing has been chosen" do
    assert_equal KioskBrowser::DEFAULT_URL, @browser.url
    refute @dir.join("kiosk-url").exist?
  end

  test "go stores an https address and restarts the kiosk" do
    assert_equal :ok, @browser.go("https://example.com/watch?v=1")
    assert_equal "https://example.com/watch?v=1", @browser.url
    assert_equal "https://example.com/watch?v=1\n", @dir.join("kiosk-url").read
    assert_equal 1, @display.restarts
  end

  test "go rejects addresses that are not http or https" do
    [ "", "javascript:alert(1)", "file:///etc/passwd", "ftp://example.com", "not a url", "http:///missing-host" ].each do |bad|
      assert_equal :invalid, @browser.go(bad), bad
    end
    assert_equal 0, @display.restarts
    assert_equal KioskBrowser::DEFAULT_URL, @browser.url
  end

  test "reset clears the override and restarts onto the display" do
    @browser.go("https://example.com")
    assert_equal :ok, @browser.reset
    assert_equal KioskBrowser::DEFAULT_URL, @browser.url
    refute @dir.join("kiosk-url").exist?
    assert_equal 2, @display.restarts
  end

  test "a failed restart leaves the previous page in place" do
    @browser.go("https://example.com/first")
    @display = FakeDisplay.new(ok: false)
    @browser = KioskBrowser.new(path: @dir.join("kiosk-url"), display: @display)

    assert_equal :failed, @browser.go("https://example.com/second")
    assert_equal "https://example.com/first", @browser.url
    assert_equal 1, @display.restarts
  end

  test "a corrupt state file is treated as the display" do
    @dir.join("kiosk-url").write("nope\n")
    assert_equal KioskBrowser::DEFAULT_URL, @browser.url
  end
end
