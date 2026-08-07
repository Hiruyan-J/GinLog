class TimelinesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]

  def index
    @sake_logs = SakeLog.includes(:user, sake: { brand: { brewery: :area } })
                        .with_attached_images
                        .order(created_at: :desc, id: :desc)
                        .page(params[:page])

    render :page if turbo_frame_request?
  end
end
