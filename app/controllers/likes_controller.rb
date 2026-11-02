# いいねの付け外しと、いいねした人の一覧
class LikesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]
  before_action :set_sake_log

  def index
    return redirect_to sake_log_path(@sake_log) unless turbo_frame_request?

    @likes = @sake_log.likes.includes(:user).order(created_at: :desc, id: :desc)
  end

  def create
    @sake_log.likes.find_or_create_by(user: current_user)
    render_like_button
  end

  def destroy
    @sake_log.likes.find_by(user: current_user)&.destroy
    render_like_button
  end

  private

  def set_sake_log
    @sake_log = SakeLog.find(params[:sake_log_id])
  end

  # いいねボタンの部分だけを Turbo Stream で差し替える
  # @return [void]
  def render_like_button
    render turbo_stream: turbo_stream.replace(
      helpers.dom_id(@sake_log, :like_button),
      partial: "likes/like_button",
      locals: { sake_log: @sake_log }
    )
  end
end
