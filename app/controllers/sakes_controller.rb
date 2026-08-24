class SakesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[show]

  def show
    @sake = Sake.includes(brand: { brewery: :area }).find(params[:id])
    # みんなの記録は 1ページ 10件（config/initializers/kaminari_config.rb の default_per_page）で、
    # 2ページ目以降は末尾の Turbo Frame から読み込まれる（無限スクロール）
    @sake_logs = @sake.sake_logs
                      .includes(:user, sake: { brand: { brewery: :area } })
                      .with_attached_images
                      .order(created_at: :desc, id: :desc)
                      .page(params[:page])

    render :page if turbo_frame_request?
  end
end
