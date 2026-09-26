require "json"
require "net/http"
require "socket"
require "timeout"
require "uri"

# Sends learned IR codes to the Haruna ESP32 over the USB bridge socket.
# An explicit http: or base_url: still uses the old Wi-Fi HTTP API.
class IrBlaster
  DEFAULT_SOCKET = "/run/ir-mc/blast.sock".freeze

  class << self
    attr_accessor :factory

    def build
      (factory || -> { new }).call
    end
  end

  def initialize(socket_path: ENV.fetch("IR_MC_SOCKET", DEFAULT_SOCKET), base_url: nil, http: nil)
    @socket_path = socket_path
    @base_url = base_url.to_s.chomp("/").presence
    @http = http
  end

  def press(remote_id, command)
    remote = IrRemote.find(remote_id)
    payload = remote&.payload_for(command)
    return false unless payload

    if http_transport?
      post("/ir/send", payload)
    else
      body = socket_exchange(payload)
      body.is_a?(Hash) && body["ok"] == true
    end
  end

  def online?
    if http_transport?
      body = get("/status")
      return false unless body

      JSON.parse(body)["tx"] == true
    else
      body = socket_exchange({ "op" => "status" })
      body.is_a?(Hash) && body["ok"] == true && body["tx"] == true
    end
  rescue JSON::ParserError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Net::OpenTimeout, Net::ReadTimeout, SocketError
    false
  end

  private

  def http_transport?
    !@http.nil? || @base_url
  end

  def http_base
    @base_url || "http://ir-mc.lan"
  end

  def socket_exchange(payload)
    Timeout.timeout(8) do
      UNIXSocket.open(@socket_path) do |sock|
        sock.puts(JSON.generate(payload))
        line = sock.gets
        return nil if line.nil? || line.strip.empty?

        JSON.parse(line)
      end
    end
  rescue Errno::ENOENT, Errno::ECONNREFUSED, Errno::EPIPE, Errno::ECONNRESET,
         SocketError, Timeout::Error, JSON::ParserError
    nil
  end

  def post(path, payload)
    uri = URI.parse("#{http_base}#{path}")
    response = http_for(uri).post(uri.request_uri, JSON.generate(payload),
                                 "Content-Type" => "application/json",
                                 "Accept" => "application/json")
    response.is_a?(Net::HTTPSuccess) && json_ok?(response.body)
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Net::OpenTimeout, Net::ReadTimeout, SocketError
    false
  end

  def get(path)
    uri = URI.parse("#{http_base}#{path}")
    response = http_for(uri).get(uri.request_uri)
    response.is_a?(Net::HTTPSuccess) ? response.body : nil
  end

  def json_ok?(body)
    JSON.parse(body)["ok"] == true
  rescue JSON::ParserError
    false
  end

  def http_for(uri)
    return @http if @http

    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 2
    http.read_timeout = 5
    http
  end
end
