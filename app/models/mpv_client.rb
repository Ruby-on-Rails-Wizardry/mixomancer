require "json"
require "socket"
require "timeout"

# JSON IPC client for the audio-cds-queue mpv process.
class MpvClient
  SOCKET = ENV.fetch("MIXOMANCER_MPV_SOCKET") {
    File.join(ENV.fetch("XDG_RUNTIME_DIR", "/run/user/2003"), "mpv-audio-cds.sock")
  }

  def initialize(path: SOCKET)
    @path = path
  end

  def available?
    File.socket?(@path)
  end

  def properties(*names)
    return {} if names.empty? || !available?

    Timeout.timeout(0.8) do
      UNIXSocket.open(@path) do |sock|
        sock.sync = true
        names.each_with_index do |name, index|
          sock.puts({ command: [ "get_property", name ], request_id: index + 1 }.to_json)
        end

        results = {}
        pending = names.size
        while pending > 0
          line = sock.gets
          break if line.nil?

          payload = JSON.parse(line)
          next unless payload["request_id"]

          name = names[payload["request_id"] - 1]
          results[name] = payload["error"] == "success" ? payload["data"] : nil
          pending -= 1
        end
        results
      end
    end
  rescue Errno::ECONNREFUSED, Errno::ENOENT, Errno::EPIPE, Errno::ETIMEDOUT, Timeout::Error, JSON::ParserError
    {}
  end

  def set_property(name, value)
    command([ "set_property", name, value ])
  end

  def command(args)
    return false unless available?

    Timeout.timeout(0.8) do
      UNIXSocket.open(@path) do |sock|
        sock.sync = true
        sock.puts({ command: args, request_id: 1 }.to_json)
        loop do
          line = sock.gets
          return false if line.nil?

          payload = JSON.parse(line)
          next unless payload["request_id"] == 1
          return payload["error"] == "success"
        end
      end
    end
  rescue Errno::ECONNREFUSED, Errno::ENOENT, Errno::EPIPE, Timeout::Error, JSON::ParserError
    false
  end
end
