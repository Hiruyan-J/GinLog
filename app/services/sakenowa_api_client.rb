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
    deleted_brewery_sakenowa_ids = import_breweries
    import_brands(deleted_brewery_sakenowa_ids)

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
      api_data = JSON.parse(response.body)
      Rails.logger.info("さけのわAPI: #{endpoint_key} の取得件数: #{api_data[endpoint_key.to_s]&.size} 件")
      api_data
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
  # @return [Array<Integer>] name空の蔵元の sakenowa_id 一覧
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

    # nameが空の酒蔵の sakenowa_id を収集(銘柄の論理削除判定用)
    deleted_brewery_sakenowa_ids = []
    # 重複統合した蔵元の件数(ログ出力用)
    merged_brewery_count = 0

    Brewery.transaction do
      breweries_data.each do |brewery_data|
        brewery = Brewery.find_or_initialize_by(sakenowa_id: brewery_data["id"])

        # nameが空のデータはさけのわ側で削除済とみなす
        if brewery_data["name"].blank?
          # 初回:プレースホルダー名を設定 / 定期更新:既存の name を維持
          brewery.name = "(名称不明)" if brewery.new_record?
          # APIのareaIdを変換マップでRailsのarea_idに変換
          brewery.area_id = area_id_map[brewery_data["areaId"]] if brewery.new_record?
          brewery.is_deleted = true
          deleted_brewery_sakenowa_ids << brewery_data["id"]
        else
          brewery.name = brewery_data["name"]
          # APIのareaIdを変換マップでRailsのarea_idに変換
          brewery.area_id = area_id_map[brewery_data["areaId"]]

          if brewery.new_record? && (merge_target = find_merge_target(brewery))
            # 新規レコードが既存の active な蔵元と name + area_id で重複
            # → 論理削除 + 統合先を記録して保存(sakenowa_id の対応関係は保持する)
            brewery.is_deleted = true
            brewery.merged_into_id = merge_target.id
            merged_brewery_count += 1
          elsif brewery.merged_into_id.nil?
            brewery.is_deleted = false
          end
        end

        brewery.save!
      end

      # 論理削除対象を特定
      Brewery.active
        .where.not(sakenowa_id: api_brewery_sakenowa_ids)
        .update_all(is_deleted: true)
    end

    Rails.logger.info("さけのわAPI: 蔵元 #{breweries_data.size} 件インポートしました（name空による論理削除: #{deleted_brewery_sakenowa_ids.size} 件、重複統合: #{merged_brewery_count} 件）")
    deleted_brewery_sakenowa_ids
  end

  # 銘柄データをAPIから取得しbrandsテーブルへインポートする
  # @param deleted_brewery_sakenowa_ids [Array<Integer>] name空の蔵元の sakenowa_id 一覧
  # @return [void]
  # @raise [RuntimeError] APIが空のデータを返した場合
  def import_brands(deleted_brewery_sakenowa_ids)
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
    # 統合済み蔵元(merged_into_id あり)は統合先の brewery_id へ解決してからマップ化
    merged_into_id_map = Brewery.merged.pluck(:id, :merged_into_id).to_h
    brewery_id_map = Brewery.pluck(:sakenowa_id, :id).to_h
      .transform_values { |brewery_id| merged_into_id_map[brewery_id] || brewery_id }

    deleted_brand_count = 0

    Brand.transaction do
      brands_data.each do |brand_data|
        brand = Brand.find_or_initialize_by(sakenowa_id: brand_data["id"])

        # name が空 または 削除済み蔵元に紐づく銘柄は論理削除
        if brand_data["name"].blank? || deleted_brewery_sakenowa_ids.include?(brand_data["breweryId"])
          if brand_data["name"].blank?
            brand.name = "(名称不明)" if brand.new_record? # nameなし:定期更新は既存 name を維持
          else
            brand.name = brand_data["name"] # nameあり:実際の名前を使う
          end
          brand.brewery_id = brewery_id_map[brand_data["breweryId"]] if brand.new_record?
          brand.is_deleted = true
          deleted_brand_count += 1
        else
          brand.name = brand_data["name"]
          brand.brewery_id = brewery_id_map[brand_data["breweryId"]]
          brand.is_deleted = false
        end

        brand.save!
      end

      Brand.active
        .where.not(sakenowa_id: api_brand_sakenowa_ids)
        .update_all(is_deleted: true)
    end

    Rails.logger.info("さけのわAPI: 銘柄 #{brands_data.size} 件インポートしました（論理削除: #{deleted_brand_count} 件）")
  end

  # 新規蔵元と name + area_id が一致する既存のactiveな蔵元を検索する
  # 統合先は常に古いID(最小ID)に統一する
  # ※ name は normalizes_text により代入時に正規化済み
  # @param brewery [Brewery] 保存前の新規 Brewery
  # @return [Brewery, nil] 統合先の蔵元(重複がなければ nil)
  def find_merge_target(brewery)
    Brewery.active
      .where(name: brewery.name, area_id: brewery.area_id)
      .order(:id)
      .first
  end
end
