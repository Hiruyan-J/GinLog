require "rails_helper"

RSpec.describe SakenowaApiClient do
  let(:client) { described_class.new }

  # ------------------------------------------------------------------
  # WebMock / fixture ヘルパー
  # ------------------------------------------------------------------

  # さけのわAPIの各エンドポイントURLを組み立てる
  def endpoint_url(endpoint_key)
    "#{SakenowaApiClient::BASE_URL}#{SakenowaApiClient::ENDPOINTS[endpoint_key]}"
  end

  # 指定エンドポイントへのGETリクエストをスタブする
  # body は文字列（JSON）でも Hash（自動で to_json）でも渡せる
  def stub_sakenowa(endpoint_key, body:, status: 200)
    body = body.to_json unless body.is_a?(String)
    stub_request(:get, endpoint_url(endpoint_key)).to_return(status: status, body: body)
  end

  # spec/fixtures/sakenowa/ 配下の JSON を文字列で読み込む
  def fixture_json(name)
    Rails.root.join("spec/fixtures/sakenowa/#{name}.json").read
  end

  # ------------------------------------------------------------------
  # fetch_data（private・send 経由で検証）
  # ------------------------------------------------------------------
  describe "#fetch_data（private）" do
    it "正常時に JSON を Hash で返す" do
      stub_sakenowa(:areas, body: fixture_json("areas"))

      result = client.send(:fetch_data, :areas)

      expect(result).to be_a(Hash)
      expect(result["areas"].size).to eq 2
      expect(result["areas"].first).to include("id" => 1, "name" => "岩手")
    end

    it "HTTP 非成功ステータス（500）で RuntimeError を raise する" do
      stub_sakenowa(:areas, body: "Internal Server Error", status: 500)

      expect { client.send(:fetch_data, :areas) }
        .to raise_error(RuntimeError, /取得に失敗しました/)
    end

    it "JSON パース失敗で RuntimeError を raise する" do
      stub_sakenowa(:areas, body: "this is not json")

      expect { client.send(:fetch_data, :areas) }
        .to raise_error(RuntimeError, /JSONパースに失敗しました/)
    end
  end


  # ------------------------------------------------------------------
  # import_areas
  # ------------------------------------------------------------------
  describe "#import_areas（private）" do
    it "正常時に Area を作成する（sakenowa_id で find_or_initialize）" do
      stub_sakenowa(:areas, body: fixture_json("areas"))

      expect { client.send(:import_areas) }.to change(Area, :count).by(2)
      expect(Area.find_by(sakenowa_id: 1).name).to eq "岩手"
    end

    it "既存の Area は sakenowa_id で特定して更新する（重複作成しない）" do
      create(:area, sakenowa_id: 1, name: "旧・岩手")
      stub_sakenowa(:areas, body: fixture_json("areas"))

      expect { client.send(:import_areas) }.to change(Area, :count).by(1)
      expect(Area.find_by(sakenowa_id: 1).name).to eq "岩手"
    end

    it "空データ（空配列）で raise し、レコードを作らない" do
      stub_sakenowa(:areas, body: { "areas" => [] })

      expect { client.send(:import_areas) }.to raise_error(RuntimeError, /データが空です/)
      expect(Area.count).to eq 0
    end

    it "空データ（nil）でも raise する" do
      stub_sakenowa(:areas, body: { "areas" => nil })

      expect { client.send(:import_areas) }.to raise_error(RuntimeError, /データが空です/)
    end
  end

  # ------------------------------------------------------------------
  # import_breweries
  # ------------------------------------------------------------------
  describe "#import_breweries（private）" do
    it "正常時に Brewery を作成し、areaId が area_id に変換される" do
      area1 = create(:area, sakenowa_id: 1)
      area2 = create(:area, sakenowa_id: 2)
      stub_sakenowa(:breweries, body: fixture_json("breweries"))

      expect { client.send(:import_breweries) }.to change(Brewery, :count).by(2)

      brewery = Brewery.find_by(sakenowa_id: 101)
      expect(brewery.name).to eq "赤武酒造"
      expect(brewery.area_id).to eq area1.id
      expect(Brewery.find_by(sakenowa_id: 102).area_id).to eq area2.id
    end

    it "空データで raise する（全件論理削除の暴発が起きない）" do
      # API に無い既存 active 蔵元。ガードが効けば論理削除されないこと
      existing = create(:brewery, sakenowa_id: 999, is_deleted: false)
      stub_sakenowa(:breweries, body: { "breweries" => [] })

      expect { client.send(:import_breweries) }.to raise_error(RuntimeError, /データが空です/)
      expect(existing.reload.is_deleted).to be false
    end

    context "name が空の蔵元" do
      let!(:area) { create(:area, sakenowa_id: 1) }

      it "初回はプレースホルダー「(名称不明)」+ is_deleted: true になる" do
        stub_sakenowa(:breweries, body: { "breweries" => [ { "id" => 101, "name" => "", "areaId" => 1 } ] })

        client.send(:import_breweries)

        brewery = Brewery.find_by(sakenowa_id: 101)
        expect(brewery.name).to eq "(名称不明)"
        expect(brewery.is_deleted).to be true
      end

      it "定期更新（既存レコードあり）は既存 name を維持する" do
        create(:brewery, sakenowa_id: 101, area: area, name: "元の蔵元名", is_deleted: false)
        stub_sakenowa(:breweries, body: { "breweries" => [ { "id" => 101, "name" => "", "areaId" => 1 } ] })

        client.send(:import_breweries)

        brewery = Brewery.find_by(sakenowa_id: 101)
        expect(brewery.name).to eq "元の蔵元名"
        expect(brewery.is_deleted).to be true
      end

      it "戻り値が name 空の蔵元の sakenowa_id 一覧になる" do
        stub_sakenowa(:breweries, body: { "breweries" => [
          { "id" => 101, "name" => "赤武酒造", "areaId" => 1 },
          { "id" => 102, "name" => "", "areaId" => 1 }
        ] })

        result = client.send(:import_breweries)
        expect(result).to eq [ 102 ]
      end
    end

    it "API 未掲載の既存 active 蔵元が is_deleted: true になる" do
      area = create(:area, sakenowa_id: 1)
      kept = create(:brewery, sakenowa_id: 101, area: area, is_deleted: false)
      removed = create(:brewery, sakenowa_id: 999, area: area, is_deleted: false)
      stub_sakenowa(:breweries, body: { "breweries" => [ { "id" => 101, "name" => "赤武酒造", "areaId" => 1 } ] })

      client.send(:import_breweries)

      expect(kept.reload.is_deleted).to be false
      expect(removed.reload.is_deleted).to be true
    end
  end

  # ------------------------------------------------------------------
  # import_brands
  # ------------------------------------------------------------------
  describe "#import_brands（private）" do
    # 銘柄インポートは蔵元マスターに依存するため、事前に蔵元を用意する
    let!(:brewery1) { create(:brewery, sakenowa_id: 101) }
    let!(:brewery2) { create(:brewery, sakenowa_id: 102) }

    it "正常時に Brand を作成し、breweryId が brewery_id に変換される" do
      stub_sakenowa(:brands, body: fixture_json("brands"))

      expect { client.send(:import_brands, []) }.to change(Brand, :count).by(2)

      brand = Brand.find_by(sakenowa_id: 1001)
      expect(brand.name).to eq "赤武"
      expect(brand.brewery_id).to eq brewery1.id
      expect(Brand.find_by(sakenowa_id: 1002).brewery_id).to eq brewery2.id
    end

    it "空データで raise する" do
      stub_sakenowa(:brands, body: { "brands" => [] })

      expect { client.send(:import_brands, []) }.to raise_error(RuntimeError, /データが空です/)
    end

    context "name が空の銘柄" do
      it "初回はプレースホルダー「(名称不明)」+ is_deleted: true になる" do
        stub_sakenowa(:brands, body: { "brands" => [ { "id" => 1001, "name" => "", "breweryId" => 101 } ] })

        client.send(:import_brands, [])

        brand = Brand.find_by(sakenowa_id: 1001)
        expect(brand.name).to eq "(名称不明)"
        expect(brand.is_deleted).to be true
      end

      it "定期更新（既存レコードあり）は既存 name を維持する" do
        create(:brand, sakenowa_id: 1001, brewery: brewery1, name: "元の銘柄名", is_deleted: false)
        stub_sakenowa(:brands, body: { "brands" => [ { "id" => 1001, "name" => "", "breweryId" => 101 } ] })

        client.send(:import_brands, [])

        brand = Brand.find_by(sakenowa_id: 1001)
        expect(brand.name).to eq "元の銘柄名"
        expect(brand.is_deleted).to be true
      end
    end

    it "削除済み蔵元に紐づく銘柄は（name があっても）is_deleted: true になる" do
      # brewery1(sakenowa_id: 101) が name 空で論理削除された想定
      stub_sakenowa(:brands, body: { "brands" => [ { "id" => 1001, "name" => "赤武", "breweryId" => 101 } ] })

      client.send(:import_brands, [ 101 ])

      brand = Brand.find_by(sakenowa_id: 1001)
      expect(brand.name).to eq "赤武"
      expect(brand.is_deleted).to be true
    end

    it "API 未掲載の既存 active 銘柄が is_deleted: true になる" do
      kept = create(:brand, sakenowa_id: 1001, brewery: brewery1, is_deleted: false)
      removed = create(:brand, sakenowa_id: 9999, brewery: brewery1, is_deleted: false)
      stub_sakenowa(:brands, body: { "brands" => [ { "id" => 1001, "name" => "赤武", "breweryId" => 101 } ] })

      client.send(:import_brands, [])

      expect(kept.reload.is_deleted).to be false
      expect(removed.reload.is_deleted).to be true
    end
  end



  # ------------------------------------------------------------------
  # import_all（統合）
  # ------------------------------------------------------------------
  describe "#import_all" do
    it "areas → breweries → brands の順で一連のインポートが成功する" do
      stub_sakenowa(:areas, body: fixture_json("areas"))
      stub_sakenowa(:breweries, body: fixture_json("breweries"))
      stub_sakenowa(:brands, body: fixture_json("brands"))

      expect { client.import_all }
        .to change(Area, :count).by(2)
        .and change(Brewery, :count).by(2)
        .and change(Brand, :count).by(2)

      # 変換マップが正しく連携していること(銘柄 → 蔵元 → エリア)
      brand = Brand.find_by(sakenowa_id: 1001)
      expect(brand.brewery.sakenowa_id).to eq 101
      expect(brand.brewery.area.sakenowa_id).to eq 1
    end

    it "途中 breweries で空データを受け取ると raise し、それ以降を実行しない" do
      stub_sakenowa(:areas, body: fixture_json("areas"))
      stub_sakenowa(:breweries, body: { "breweries" => [] })
      brands_stub = stub_sakenowa(:brands, body: fixture_json("brands"))

      expect { client.import_all }.to raise_error(RuntimeError, /データが空です/)
      # brand エンドポイントは呼ばれない
      expect(brands_stub).not_to have_been_requested
    end
  end
end
