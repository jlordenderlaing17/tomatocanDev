class InvitesController < ApplicationController
  def invite_received
    # create cookie
    cookies[:referer_id] = {
        value: params[:referer_id],
        expires: 1.month.from_now
    }
    # trigger redirect
    redirect_to "/"
  end
end
