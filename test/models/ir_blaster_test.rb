require "test_helper"

class IrBlasterTest < ActiveSupport::TestCase
  class FakeHttp
    attr_reader :posts

    def initialize(ok: true)
      @ok = ok
      @posts = []
    end

    def post(path, body, _headers)
      @posts << [ path, JSON.parse(body) ]
      status = @ok ? "200" : "500"
      klass = @ok ? Net::HTTPOK : Net::HTTPInternalServerError
      response = klass.new("1.1", status, @ok ? "OK" : "ERR")
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, @ok ? '{"ok":true}' : '{"ok":false}')
      def response.body
        @body
      end
      response
    end

    def get(_path)
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, '{"tx":true}')
      def response.body
        @body
      end
      response
    end
  end

  test "press posts protocol JSON to /ir/send" do
    http = FakeHttp.new
    blaster = IrBlaster.new(base_url: "http://ir-mc.lan", http: http)

    assert blaster.press("sceptre", "power")
    path, body = http.posts.first
    assert_equal "/ir/send", path
    assert_equal "sony", body["protocol"]
    assert_equal 1, body["address"]
    assert_equal 21, body["command"]
  end

  test "press returns false when the blaster errors" do
    http = FakeHttp.new(ok: false)
    blaster = IrBlaster.new(http: http)
    assert_not blaster.press("sceptre", "mute")
  end

  test "press returns false for an unknown button" do
    http = FakeHttp.new
    blaster = IrBlaster.new(http: http)
    assert_not blaster.press("sceptre", "nope")
    assert_empty http.posts
  end

  test "online? reads tx from /status" do
    assert IrBlaster.new(http: FakeHttp.new).online?
  end
end
