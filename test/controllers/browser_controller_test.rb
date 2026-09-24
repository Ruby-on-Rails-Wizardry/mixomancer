require "test_helper"

class BrowserControllerTest < ActionDispatch::IntegrationTest
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
    KioskBrowser.factory = ->(*) { @browser }
  end

  teardown do
    KioskBrowser.factory = nil
    FileUtils.remove_entry(@dir) if @dir&.exist?
  end

  test "browser page shows the display url with go and back buttons" do
    get browser_url
    assert_response :success
    assert_select "h1", "Browser"
    assert_select "nav a[href=?]", browser_path, text: "Browser"
    assert_select "input[name=url][value=?]", KioskBrowser::DEFAULT_URL
    assert_select "form[action=?] button", browser_path, text: "Go"
    assert_select "form[action=?] button", reset_browser_path, text: "Back to display"
  end

  test "go switches the kiosk and comes back to the page" do
    post browser_url, params: { url: "https://example.com/watch" }
    assert_redirected_to browser_url
    assert_equal "https://example.com/watch", @browser.url
    assert_equal 1, @display.restarts
    follow_redirect!
    assert_match "The kiosk is opening that page.", response.body
    assert_select "input[name=url][value=?]", "https://example.com/watch"
  end

  test "go rejects a non-http address" do
    post browser_url, params: { url: "javascript:alert(1)" }
    assert_redirected_to browser_url
    assert_equal 0, @display.restarts
    follow_redirect!
    assert_match "Enter an http or https address.", response.body
    assert_select "input[name=url][value=?]", KioskBrowser::DEFAULT_URL
  end

  test "back to display clears the override" do
    @browser.go("https://example.com")
    post reset_browser_url
    assert_redirected_to browser_url
    assert_equal KioskBrowser::DEFAULT_URL, @browser.url
    follow_redirect!
    assert_match "The kiosk is back on the display.", response.body
  end

  test "a failed restart shows an alert" do
    @display = FakeDisplay.new(ok: false)
    @browser = KioskBrowser.new(path: @dir.join("kiosk-url"), display: @display)
    KioskBrowser.factory = ->(*) { @browser }

    post browser_url, params: { url: "https://example.com" }
    assert_redirected_to browser_url
    follow_redirect!
    assert_match "Could not switch the kiosk browser.", response.body
    assert_select "input[name=url][value=?]", KioskBrowser::DEFAULT_URL
  end
end
