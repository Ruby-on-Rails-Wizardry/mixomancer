require "test_helper"
require "socket"

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

  test "press sends protocol JSON over the usb socket" do
    dir = Dir.mktmpdir
    path = File.join(dir, "blast.sock")
    received = nil
    server = UNIXServer.new(path)
    thread = Thread.new do
      client = server.accept
      received = JSON.parse(client.gets)
      client.puts('{"ok":true,"tx":true}')
      client.close
    end

    assert IrBlaster.new(socket_path: path).press("sceptre", "power")
    thread.join(2)
    assert_equal "sony", received["protocol"]
    assert_equal 1, received["address"]
    assert_equal 21, received["command"]
    assert_equal 40000, received["freq"]
  ensure
    server&.close
    FileUtils.remove_entry(dir) if dir
  end

  test "online? is true when the usb bridge reports tx" do
    dir = Dir.mktmpdir
    path = File.join(dir, "blast.sock")
    server = UNIXServer.new(path)
    thread = Thread.new do
      client = server.accept
      JSON.parse(client.gets)
      client.puts('{"ok":true,"tx":true}')
      client.close
    end

    assert IrBlaster.new(socket_path: path).online?
    thread.join(2)
  ensure
    server&.close
    FileUtils.remove_entry(dir) if dir
  end

  test "online? is false when the usb socket is missing" do
    assert_not IrBlaster.new(socket_path: "/tmp/ir-mc-missing-#{Process.pid}.sock").online?
  end
end
