require "net/http"

# さけのわデータAPIからエリア・蔵元・銘柄データを取得しDBへインポートするクライアント
# @see https://muro.sakenowa.com/sakenowa-data/
class SakenowaApiClient
  BASE_URL = "https://muro.sakenowa.com/sakenowa-data/api"

  ENDPOINTS = {
    areas: "/areas",
    breweries: "/breweries",
    brands: "/brands"
  }.freeze

  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 30

  # 全データを一括インポート（areas → breweries → brands の順）
  # @return [void]
  # @raise [RuntimeError] API通信に失敗した場合
  def import_all
    Rails.logger.info("さけのわAPI: データインポートを開始します")

    import_areas
    import_breweries
    import_brands

    Rails.logger.info("さけのわAPI: データインポートが完了しました")
  end

  private

  # APIからJSONデータを取得する共通メソッド
  # @param endpoint_key [Symbol] エンドポイントのキー（:areas, :breweries, :brands）
  # @return [Hash] パース済みのJSONレスポンス
  # @raise [RuntimeError] HTTPリクエストが失敗した場合、またはJSONパースに失敗した場合
  def fetch_data(endpoint_key)
    url = URI.parse("#{BASE_URL}#{ENDPOINTS[endpoint_key]}")

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    request = Net::HTTP::Get.new(url.request_uri)
    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise "さけのわAPI エラー: #{endpoint_key} の取得に失敗しました（ステータス: #{response.code}）"
    end

    begin
      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise "さけのわAPI エラー: #{endpoint_key} のJSONパースに失敗しました（#{e.message}）"
    end
  end

  # エリア（都道府県）データをAPIから取得しareasテーブルへインポートする
  # @return [void]
  # @raise [RuntimeError] APIが空のデータを返した場合
  def import_areas
    response = fetch_data(:areas)
    areas_data = response["areas"]

    # 空データは異常とみなしてインポートを中止(nil + 空配列チェック)
    if areas_data.blank?
      raise "さけのわAPI エラー: areas のデータが空です。インポートを中止します"
    end

    Area.transaction do
      areas_data.each do |area_data|
        area = Area.find_or_initialize_by(sakenowa_id: area_data["id"])
        area.name = area_data["name"]
        area.save!
      end
    end

    Rails.logger.info("さけのわAPI: エリア #{areas_data.size} 件インポートしました")
  end

  # 蔵元データをAPIから取得しbreweriesテーブルへインポートする
  # @return [void]
  # @raise [RuntimeError] APIが空のデータを返した場合
  def import_breweries
    response = fetch_data(:breweries)
    breweries_data = response["breweries"]

    # 空データは異常とみなしてインポートを中止(nil + 空配列チェック)
    # 空配列のまま進むと where.not(sakenowa_id: []) が全件にマッチし、
    # 全銘柄が論理削除されてしまうため必須のガード
    if breweries_data.blank?
      raise "さけのわAPI エラー: breweries のデータが空です。インポートを中止します"
    end

    api_brewery_sakenowa_ids = breweries_data.map { |b| b["id"] }

    # さけのわAPIのエリアID → RailsのエリアIDの変換マップの事前作成(N+1対策)
    area_id_map = Area.pluck(:sakenowa_id, :id).to_h

    Brewery.transaction do
      breweries_data.each do |brewery_data|
        brewery = Brewery.find_or_initialize_by(sakenowa_id: brewery_data["id"])
        brewery.name = brewery_data["name"]
        # APIのareaIdを変換マップでRailsのarea_idに変換
        brewery.area_id = area_id_map[brewery_data["areaId"]]
        brewery.is_deleted = false
        brewery.save!
      end

      # 論理削除対象を特定
      Brewery.active
        .where.not(sakenowa_id: api_brewery_sakenowa_ids)
        .update_all(is_deleted: true)
    end

    Rails.logger.info("さけのわAPI: 蔵元 #{breweries_data.size} 件インポートしました")
  end

  # 銘柄データをAPIから取得しbrandsテーブルへインポートする
  # @return [void]
  # @raise [RuntimeError] APIが空のデータを返した場合
  def import_brands
    response = fetch_data(:brands)
    brands_data = response["brands"]

    # 空データは異常とみなしてインポートを中止(nil + 空配列チェック)
    # 空配列のまま進むと where.not(sakenowa_id: []) が全件にマッチし、
    # 全銘柄が論理削除されてしまうため必須のガード
    if brands_data.blank?
      raise "さけのわAPI エラー: brands のデータが空です。インポートを中止します"
    end

    api_brand_sakenowa_ids = brands_data.map { |b| b["id"] }
    # さけのわAPIの蔵元ID → Railsの蔵元IDの変換マップの事前作成(N+1対策)
    brewery_id_map = Brewery.pluck(:sakenowa_id, :id).to_h

    Brand.transaction do
      brands_data.each do |brand_data|
        brand = Brand.find_or_initialize_by(sakenowa_id: brand_data["id"])
        brand.name = brand_data["name"]
        brand.brewery_id = brewery_id_map[brand_data["breweryId"]]
        brand.is_deleted = false
        brand.save!
      end

      Brand.active
        .where.not(sakenowa_id: api_brand_sakenowa_ids)
        .update_all(is_deleted: true)
    end

    Rails.logger.info("さけのわAPI: 銘柄 #{brands_data.size} 件インポートしました")
  end
end
