# 銘柄オートコンプリート検索用APIコントローラ
class Api::BrandsController < ApplicationController
  # GET /api/brands/search?q=赤武
  # 銘柄名で部分一致検索し、蔵元・都道府県情報を含むJSONを返す
  # @return [void] JSON形式で銘柄候補を返す
  def search
    query = params[:q].to_s.strip

    if query.blank?
      render json: { brands: [] }
      return
    end

    brands = Brand.search_by_name(query)

    render json: {
      brands: brands.map { |brand|
        {
          id: brand.id,
          name: brand.name,
          brewery_name: brand.brewery.name,
          area_name: brand.brewery.area.name,
          # 重複銘柄を区別するためのラベル（例: 「赤武 - 赤武酒造（岩手県）」）
          label: "#{brand.name} - #{brand.brewery.name} (#{brand.brewery.area.name})"
        }
      }
    }
  end
end
