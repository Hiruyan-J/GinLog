class SakesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index show]

  # GET /sakes?keyword=xxx
  # フリーワードで日本酒を検索する。未入力なら検索せず、入力を促す画面を出す
  # @return [void]
  def index
    @keyword = params[:keyword].to_s
    # 1ページ 10件。2ページ目以降は末尾の Turbo Frame から読み込まれる（無限スクロール）
    # 銘柄名が完全一致するものが先頭。その中で記録が多い順に並べる
    @sakes = Sake.search_by_keyword(@keyword)
                 .includes(brand: { brewery: :area })
                 .order(sake_logs_count: :desc, id: :desc)
                 .page(params[:page])

    render :search_page if turbo_frame_request?
  end

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
