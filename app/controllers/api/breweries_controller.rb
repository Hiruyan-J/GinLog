# 蔵元オートコンプリート検索用APIコントローラ
class Api::BreweriesController < ApplicationController
  # GET /api/breweries/search?q=朝日
  # 蔵元名で部分一致検索し、都道府県情報を含むJSONを返す
  # @return [void] JSON形式で蔵元候補を返す
  def search
    query = params[:q].to_s.strip

    if query.blank?
      render json: { breweries: [] }
      return
    end

    breweries = Brewery.search_by_name(query)

    render json: {
      breweries: breweries.map { |brewery|
        {
          id: brewery.id,
          name: brewery.name,
          area_id: brewery.area.id,
          area_name: brewery.area.name,
          # 重複蔵元を区別するためのラベル（例: 「朝日酒造（新潟県）」）
          label: "#{brewery.name}（#{brewery.area.name}）"
        }
      }
    }
  end
end
