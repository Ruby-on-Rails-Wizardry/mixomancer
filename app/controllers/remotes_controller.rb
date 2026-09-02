class RemotesController < ApplicationController
  def index
    @remotes = IrRemote.all
    @blaster_online = IrBlaster.build.online?
  end

  def show
    @remote = IrRemote.find(params[:id])
    return redirect_to remotes_path, alert: "Unknown remote." unless @remote

    @blaster_online = IrBlaster.build.online?
  end

  def press
    remote = IrRemote.find(params[:id])
    unless remote&.button(params[:command])
      return head :not_found if request.format.json?

      return redirect_to remotes_path, alert: "Unknown remote or button."
    end

    ok = IrBlaster.build.press(params[:id], params[:command])
    if request.format.json?
      return head(ok ? :no_content : :bad_gateway)
    end

    if ok
      redirect_to remote_path(params[:id]), status: :see_other
    else
      redirect_to remote_path(params[:id]), alert: "IR blast failed. Is the Haruna ESP32 up?", status: :see_other
    end
  end
end
