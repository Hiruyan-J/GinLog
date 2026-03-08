# 商品名オートコンプリート検索用APIコントローラ
class Api::SakesController < ApplicationController
  # GET /api/sakes/search?brand_id=123&q=恵
  # 指定された銘柄に紐づく商品名を部分一致検索し、JSONを返す
  # @return [void] JSON形式で商品名候補を返す
  def search
    brand_id = params[:brand_id]
    query = params[:q].to_s.strip

    # brand_idが未指定の場合は空配列を返す
    if brand_id.blank?
      render json: { sakes: [] }
      return
    end

    sakes = if query.blank?
              # クエリが空の場合は、銘柄に紐づく全商品を返す
              Sake.where(brand_id: brand_id)
    else
              Sake.search_by_product_name(brand_id, query)
    end

    render json: {
      sakes: sakes.map { |sake|
        {
          id: sake.id,
          product_name: sake.product_name
        }
      }
    }
  end
end
