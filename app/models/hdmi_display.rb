# HDMI kiosk/video units are system-level (need DRM + chvt).
class HdmiDisplay
  KIOSK_UNIT = "mixomancer-kiosk.service"
  VIDEO_UNIT = "mixomancer-video.service"
  CONTROL_URL = ENV.fetch("MIXOMANCER_URL", "http://haruna.lan")

  def self.ensure_kiosk
    systemctl("start", KIOSK_UNIT)
  end

  def self.start_video
    systemctl("start", VIDEO_UNIT)
  end

  def self.stop_video
    systemctl("stop", VIDEO_UNIT)
  end

  def self.video_active?
    systemctl("is-active", "--quiet", VIDEO_UNIT)
  end

  def self.kiosk_active?
    systemctl("is-active", "--quiet", KIOSK_UNIT)
  end

  def self.systemctl(*args)
    system("sudo", "-n", "systemctl", *args)
  end
end
