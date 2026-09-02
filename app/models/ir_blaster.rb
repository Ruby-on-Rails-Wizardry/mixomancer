require "json"
require "net/http"
require "uri"

# Forwards learned IR codes to the Haruna ESP32 ir_bridge over HTTP.
class IrBlaster
  DEFAULT_URL = "http://ir-mc.lan".freeze

  class << self
    attr_accessor :factory

    def build
      (factory || -> { new }).call
    end
  end

  def initialize(base_url: ENV.fetch("IR_MC_URL", DEFAULT_URL), http: nil)
    @base_url = base_url.to_s.chomp("/")
    @http = http
  end

  def press(remote_id, command)
    remote = IrRemote.find(remote_id)
    payload = remote&.payload_for(command)
    return false unless payload

    post("/ir/send", payload)
  end

  def online?
    body = get("/status")
    return false unless body

    JSON.parse(body)["tx"] == true
  rescue JSON::ParserError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Net::OpenTimeout, Net::ReadTimeout, SocketError
    false
  end

  private

  def post(path, payload)
    uri = URI.parse("#{@base_url}#{path}")
    response = http_for(uri).post(uri.request_uri, JSON.generate(payload),
                                 "Content-Type" => "application/json",
                                 "Accept" => "application/json")
    response.is_a?(Net::HTTPSuccess) && json_ok?(response.body)
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Net::OpenTimeout, Net::ReadTimeout, SocketError
    false
  end

  def get(path)
    uri = URI.parse("#{@base_url}#{path}")
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
