class BrowserController < ApplicationController
  def show
    @kiosk = KioskBrowser.build
  end

  def go
    case KioskBrowser.build.go(params[:url])
    when :ok
      redirect_to browser_path, notice: "The kiosk is opening that page.", status: :see_other
    when :invalid
      redirect_to browser_path, alert: "Enter an http or https address.", status: :see_other
    else
      redirect_to browser_path, alert: "Could not switch the kiosk browser.", status: :see_other
    end
  end

  def reset
    if KioskBrowser.build.reset == :ok
      redirect_to browser_path, notice: "The kiosk is back on the display.", status: :see_other
    else
      redirect_to browser_path, alert: "Could not switch the kiosk browser.", status: :see_other
    end
  end
end
