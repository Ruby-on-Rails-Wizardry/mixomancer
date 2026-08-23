require "test_helper"
require "socket"

class MpvClientTest < ActiveSupport::TestCase
  setup do
    @dir = Dir.mktmpdir("mpv-ipc")
    @path = File.join(@dir, "mpv.sock")
    @server = UNIXServer.new(@path)
    @props = {
      "path" => "/mnt/audio_cds/calming_forest_sounds/Track 1.wav",
      "pause" => false,
      "time-pos" => 12.0,
      "duration" => 60.0
    }
    @thread = Thread.new { run_server }
  end

  teardown do
    @thread&.kill
    @server.close rescue nil
    FileUtils.remove_entry(@dir)
  end

  test "available when the socket exists" do
    assert MpvClient.new(path: @path).available?
    refute MpvClient.new(path: File.join(@dir, "missing.sock")).available?
  end

  test "properties reads mpv JSON IPC" do
    client = MpvClient.new(path: @path)
    result = client.properties("path", "pause", "time-pos")

    assert_equal "/mnt/audio_cds/calming_forest_sounds/Track 1.wav", result["path"]
    assert_equal false, result["pause"]
    assert_equal 12.0, result["time-pos"]
  end

  test "set_property writes through IPC" do
    client = MpvClient.new(path: @path)
    assert client.set_property("pause", true)
    assert_equal true, @props["pause"]
  end

  test "properties is empty when the socket is missing" do
    assert_equal ({}), MpvClient.new(path: File.join(@dir, "missing.sock")).properties("path")
  end

  private

  def run_server
    loop do
      client = @server.accept
      Thread.new(client) do |sock|
        sock.each_line do |line|
          payload = JSON.parse(line)
          command = payload["command"]
          request_id = payload["request_id"]
          case command[0]
          when "get_property"
            name = command[1]
            if @props.key?(name)
              sock.puts({ error: "success", data: @props[name], request_id: request_id }.to_json)
            else
              sock.puts({ error: "property not found", request_id: request_id }.to_json)
            end
          when "set_property"
            @props[command[1]] = command[2]
            sock.puts({ error: "success", request_id: request_id }.to_json)
          end
        end
      rescue StandardError
        # Client closed the socket.
      ensure
        sock.close
      end
    end
  rescue IOError, Errno::EBADF
    # Server closed during teardown.
  end
end
