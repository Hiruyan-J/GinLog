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

    context "蔵元の重複統合(merged_into_id)" do
      let!(:area) { create(:area, sakenowa_id: 1) }

      it "新規レコードが既存 active な蔵元と name + area_id で重複 → 論理削除 + merged_into_id を記録する" do
        existing = create(:brewery, sakenowa_id: 305, area: area, name: "朝日酒造", is_deleted: false)
        stub_sakenowa(:breweries, body: { "breweries" => [
          { "id" => 305, "name" => "朝日酒造", "areaId" => 1 },
          { "id" => 909, "name" => "朝日酒造", "areaId" => 1 }
        ] })

        client.send(:import_breweries)

        duplicated = Brewery.find_by(sakenowa_id: 909)
        expect(duplicated.is_deleted).to be true
        expect(duplicated.merged_into).to eq existing
        # 統合先は active のまま維持される
        expect(existing.reload.is_deleted).to be false
      end

      it "name, area_id の両方が一致しない蔵元は統合しない" do
        create(:area, sakenowa_id: 2)
        create(:brewery, sakenowa_id: 305, area: area, name: "朝日酒造", is_deleted: false)
        stub_sakenowa(:breweries, body: { "breweries" => [
          { "id" => 305, "name" => "朝日酒造", "areaId" => 1 },
          { "id" => 808, "name" => "朝日酒造", "areaId" => 2 },
          { "id" => 909, "name" => "新政酒造", "areaId" => 1 }
        ] })

        client.send(:import_breweries)

        aggregate_failures do
          # name は同じだが別エリア
          same_name_other_area = Brewery.find_by(sakenowa_id: 808)
          expect(same_name_other_area.is_deleted).to be false
          expect(same_name_other_area.merged_into_id).to be_nil

          # 同じエリアだが name が違う
          same_area_other_name = Brewery.find_by(sakenowa_id: 909)
          expect(same_area_other_name.is_deleted).to be false
          expect(same_area_other_name.merged_into_id).to be_nil
        end
      end

      it "統合済み既存レコード（merged_into_id あり）は、APIに name ありで再登場しても is_deleted を false に巻き戻さない" do
        merge_target = create(:brewery, sakenowa_id: 305, area: area, name: "朝日酒造", is_deleted: false)
        merged = create(:brewery, sakenowa_id: 909, area: area, name: "朝日酒造",
                        is_deleted: true, merged_into: merge_target)
        stub_sakenowa(:breweries, body: { "breweries" => [
          { "id" => 305, "name" => "朝日酒造", "areaId" => 1 },
          { "id" => 909, "name" => "朝日酒造", "areaId" => 1 }
        ] })

        client.send(:import_breweries)

        expect(merged.reload.is_deleted).to be true
        expect(merged.merged_into).to eq merge_target
      end

      it "論理削除済みの同名蔵元は統合先にならない" do
        create(:brewery, sakenowa_id: 305, area: area, name: "朝日酒造", is_deleted: true)
        # 305 は API 未掲載なので論理削除のまま。909 だけが新規で入る
        stub_sakenowa(:breweries, body: { "breweries" => [
          { "id" => 909, "name" => "朝日酒造", "areaId" => 1 }
        ] })

        client.send(:import_breweries)

        new_brewery = Brewery.find_by(sakenowa_id: 909)
        expect(new_brewery.merged_into_id).to be_nil
        expect(new_brewery.is_deleted).to be false
      end

      it "3件以上の重複はすべて最小IDの蔵元へ統合される" do
        stub_sakenowa(:breweries, body: { "breweries" => [
          { "id" => 305, "name" => "朝日酒造", "areaId" => 1 },
          { "id" => 909, "name" => "朝日酒造", "areaId" => 1 },
          { "id" => 918, "name" => "朝日酒造", "areaId" => 1 }
        ] })

        client.send(:import_breweries)

        # 最初に保存された 305 が統合先(最小ID)として active のまま残る
        merge_target = Brewery.find_by(sakenowa_id: 305)
        expect(merge_target.is_deleted).to be false
        expect(merge_target.merged_into_id).to be_nil

        merged = Brewery.where(sakenowa_id: [ 909, 918 ])
        expect(merged.pluck(:is_deleted)).to all(be true)
        expect(merged.pluck(:merged_into_id)).to all(eq merge_target.id)
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

    it "空データで raise する（全件論理削除の暴発が起きない）" do
      existing = create(:brand, sakenowa_id: 9999, brewery: brewery1, is_deleted: false)
      stub_sakenowa(:brands, body: { "brands" => [] })

      expect { client.send(:import_brands, []) }.to raise_error(RuntimeError, /データが空です/)
      expect(existing.reload.is_deleted).to be false
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

    context "統合済み蔵元の銘柄" do
      it "merged_into_id がある蔵元の銘柄は統合先の brewery_id で保存される" do
        create(:brewery, sakenowa_id: 909, merged_into: brewery1, is_deleted: true)
        stub_sakenowa(:brands, body: { "brands" => [ { "id" => 1001, "name" => "得月", "breweryId" => 909 } ] })

        client.send(:import_brands, [])

        brand = Brand.find_by(sakenowa_id: 1001)
        expect(brand.brewery_id).to eq brewery1.id
        expect(brand.is_deleted).to be false
      end

      it "既存銘柄が統合前の蔵元に紐づいている場合、再importで統合先へ付け替わる" do
        merged_brewery = create(:brewery, sakenowa_id: 909, merged_into: brewery1, is_deleted: true)
        brand = create(:brand, sakenowa_id: 1001, brewery: merged_brewery, name: "得月", is_deleted: false)
        stub_sakenowa(:brands, body: { "brands" => [ { "id" => 1001, "name" => "得月", "breweryId" => 909 } ] })

        client.send(:import_brands, [])

        expect(brand.reload.brewery_id).to eq brewery1.id
        expect(brand.is_deleted).to be false
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

    it "name 空の蔵元に紐づく銘柄まで連鎖して論理削除される (breweries→brands の受け渡し)" do
      stub_sakenowa(:areas, body: { "areas" => [ { "id" => 1, "name" => "岩手" } ] })
      stub_sakenowa(:breweries, body: { "breweries" => [
        { "id" => 101, "name" => "", "areaId" => 1 },
        { "id" => 102, "name" => "新政酒造", "areaId" => 1 }
      ] })
      stub_sakenowa(:brands, body: { "brands" => [
        { "id" => 1001, "name" => "赤武", "breweryId" => 101 },
        { "id" => 1002, "name" => "No.6", "breweryId" => 102 }
      ] })

      client.import_all

      # 削除された蔵元(101)の銘柄は、name があっても連鎖で論理削除される（配線が効いるかの確認）
      expect(Brand.find_by(sakenowa_id: 1001).is_deleted).to be true
      expect(Brand.find_by(sakenowa_id: 1002).is_deleted).to be false
    end

    it "重複蔵元を含む import を2回実行しても結果が同じ（冪等性）" do
      stub_sakenowa(:areas, body: { "areas" => [ { "id" => 1, "name" => "新潟" } ] })
      stub_sakenowa(:breweries, body: { "breweries" => [
        { "id" => 305, "name" => "朝日酒造", "areaId" => 1 },
        { "id" => 909, "name" => "朝日酒造", "areaId" => 1 }
      ] })
      stub_sakenowa(:brands, body: { "brands" => [
        { "id" => 1001, "name" => "久保田", "breweryId" => 305 },
        { "id" => 1002, "name" => "得月", "breweryId" => 909 }
      ] })

      client.import_all

      # 2回目の実行で蔵元・銘柄の状態が一切変わらないこと
      expect { client.import_all }.not_to change {
        [
          Brewery.order(:id).pluck(:sakenowa_id, :is_deleted, :merged_into_id),
          Brand.order(:id).pluck(:sakenowa_id, :brewery_id, :is_deleted)
        ]
      }

      # 全銘柄が統合先(古いID側)へ集約されていること
      merge_target = Brewery.find_by(sakenowa_id: 305)
      expect(merge_target.brands.active.pluck(:name)).to contain_exactly("久保田", "得月")
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
