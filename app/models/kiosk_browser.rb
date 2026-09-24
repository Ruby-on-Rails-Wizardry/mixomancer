# Where the HDMI kiosk browser should point. No state file means the now-playing display.
class KioskBrowser
  DEFAULT_URL = "http://127.0.0.1/display"
  STATE_FILE = Pathname.new(ENV.fetch("MIXOMANCER_STATE_DIR", "/var/lib/mixomancer")).join("kiosk-url")

  class << self
    attr_accessor :factory

    def build(...)
      factory ? factory.call(...) : new(...)
    end
  end

  def initialize(path: STATE_FILE, display: HdmiDisplay)
    @path = Pathname.new(path)
    @display = display
  end

  def url
    return DEFAULT_URL unless @path.file?

    normalize(@path.read) || DEFAULT_URL
  end

  def default_url
    DEFAULT_URL
  end

  def go(raw)
    target = normalize(raw)
    return :invalid unless target

    switch(target)
  end

  def reset
    switch(DEFAULT_URL)
  end

  private

  def switch(target)
    previous = @path.file? ? @path.read : nil
    return :failed unless store(target)
    return :ok if @display.restart_kiosk

    restore(previous)
    :failed
  end

  def store(target)
    if target == DEFAULT_URL
      @path.delete if @path.exist?
    else
      @path.dirname.mkpath
      @path.write("#{target}\n")
    end
    true
  rescue SystemCallError
    false
  end

  def restore(previous)
    if previous.nil?
      @path.delete if @path.exist?
    else
      @path.dirname.mkpath
      @path.write(previous)
    end
  rescue SystemCallError
    nil
  end

  def normalize(raw)
    text = raw.to_s.strip
    return if text.empty? || text.length > 2048
    return if text.match?(/[[:space:][:cntrl:]]/)

    uri = URI.parse(text)
    return unless uri.is_a?(URI::HTTP) && %w[http https].include?(uri.scheme)
    return if uri.host.blank?

    uri.to_s
  rescue URI::InvalidURIError
    nil
  end
end
