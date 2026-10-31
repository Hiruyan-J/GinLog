class SakesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index show]

  # GET /sakes?keyword=xxx
  # GET /sakes?brand_id=1（brewery_id / area_id も同じ。keyword と組み合わせ可）
  # GET /sakes?quadrants[]=aroma_high_taste_light（4象限。複数指定可）
  # フリーワードと銘柄・蔵元・都道府県・4象限で日本酒を検索する。未入力なら全件を表示する
  # @return [void]
  def index
    @keyword = params[:keyword].to_s
    # 絞り込み条件（キー => レコード）。存在しない ID は条件ごと無視する
    @filters = {
      brand_id: find_filter(Brand, :brand_id),
      brewery_id: find_filter(Brewery, :brewery_id),
      area_id: find_filter(Area, :area_id)
    }.compact

    # 選んだ象限。決まったキー以外の値は無視する（Array.wrap は nil（象限なし）を [] に、1つの値を配列にする）
    @quadrants = Array.wrap(params[:quadrants]) & TasteAromaQuadrant::KEYS
    @filter_params = @filters.transform_values(&:id)  # URL やフォームに引き継ぐ形（キー => ID）
    @filter_params[:quadrants] = @quadrants if @quadrants.any?  # 象限も引き継ぐ（quadrants: ["aroma_high_taste_light", ...] の形）

    # 1ページ 10件。2ページ目以降は末尾の Turbo Frame から読み込まれる（無限スクロール）
    # 銘柄名が完全一致するものが先頭。その中で記録が多い順に並べる
    @sakes = Sake.search_by_keyword(@keyword)
                 .filter_by_ids(**@filter_params.except(:quadrants))
                 .filter_by_quadrants(@quadrants)
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

  private

  # 絞り込み条件の ID からレコードを探す
  # @param model [Class] 探すモデル（Brand / Brewery / Area）
  # @param key [Symbol] パラメータ名（:brand_id など）
  # @return [ApplicationRecord, nil] 未指定・存在しない ID なら nil
  def find_filter(model, key)
    model.find_by(id: params[key]) if params[key].present?
  end
end
