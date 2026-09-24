require "rails_helper"

RSpec.describe LabelExtraction::Extractor do
  let(:endpoint) { %r{generativelanguage\.googleapis\.com/v1beta/models/.+:generateContent} }
  let(:front_image) { { mime_type: "image/jpeg", data: "front-binary" } }
  let(:back_image) { { mime_type: "image/jpeg", data: "back-binary" } }

  before do
    ENV["GEMINI_API_KEY"] = "test-api-key"
  end

  after do
    ENV.delete("GEMINI_API_KEY")
  end

  # Gemini API が extraction を返すようにスタブする
  # @param extraction [Hash] 抽出結果として返す内容（不足キーは nil で補完）
  # @return [void]
  def stub_gemini(extraction)
    defaults = {
      brand_name: nil, product_name: nil, product_name_alternatives: [],
      brewery_name: nil, brewery_name_raw: nil, prefecture: nil, confidence: "high"
    }
    body = {
      candidates: [
        { content: { parts: [ { text: defaults.merge(extraction).to_json } ] }, finishReason: "STOP" }
      ]
    }.to_json
    stub_request(:post, endpoint).to_return(status: 200, body: body)
  end

  describe "#call" do
    context "銘柄がマスタに1件だけ一致する場合" do
      let!(:brand) do
        create(:brand, name: "屋守",
               brewery: create(:brewery, name: "豊島屋酒造", area: create(:area, name: "東京都")))
      end

      before do
        stub_gemini(brand_name: "屋守", product_name: "純米中取り 無調整生",
                    brewery_name: "豊島屋酒造", brewery_name_raw: "豊島屋酒造株式会社", prefecture: "東京都")
      end

      it "brand_match が single になり、候補に蔵元・都道府県の情報が入る" do
        result = described_class.new(front_image: front_image).call

        expect(result[:brand_match][:status]).to eq("single")
        candidate = result[:brand_match][:candidates].first
        expect(candidate[:id]).to eq(brand.id)
        expect(candidate[:brewery_name]).to eq("豊島屋酒造")
        expect(candidate[:area_name]).to eq("東京都")
        expect(candidate[:label]).to eq("屋守 - 豊島屋酒造 (東京都)")
      end

      it "都道府県がマスタと照合される" do
        result = described_class.new(front_image: front_image).call

        expect(result[:area]).to eq(id: brand.brewery.area.id, name: "東京都")
      end
    end

    context "同名の銘柄が複数ある場合" do
      before do
        create(:brand, name: "亀齢", brewery: create(:brewery, name: "亀齢酒造", area: create(:area, name: "広島県")))
        create(:brand, name: "亀齢", brewery: create(:brewery, name: "岡崎酒造", area: create(:area, name: "長野県")))
        stub_gemini(brand_name: "亀齢")
      end

      it "brand_match が multiple になり候補が2件返る" do
        result = described_class.new(front_image: front_image).call

        expect(result[:brand_match][:status]).to eq("multiple")
        expect(result[:brand_match][:candidates].size).to eq(2)
      end
    end

    context "同名の銘柄が複数あり、蔵元名も読み取れている場合" do
      before do
        create(:brand, name: "どぶろく", brewery: create(:brewery, name: "酒田醗酵", area: create(:area, name: "山形県")))
        create(:brand, name: "どぶろく", brewery: create(:brewery, name: "熊澤酒造", area: create(:area, name: "神奈川県")))
        create(:brand, name: "どぶろく", brewery: create(:brewery, name: "千代酒造", area: create(:area, name: "奈良県")))
        stub_gemini(brand_name: "どぶろく", brewery_name: "熊澤酒造", prefecture: "神奈川県")
      end

      it "候補を減らさず、蔵元が一致するものを先頭に並べる" do
        result = described_class.new(front_image: front_image).call

        candidates = result[:brand_match][:candidates]
        expect(candidates.size).to eq(3)
        expect(candidates.first[:brewery_name]).to eq("熊澤酒造")
      end
    end

    context "同名の銘柄が複数あり、都道府県しか読み取れていない場合" do
      before do
        create(:brand, name: "高砂", brewery: create(:brewery, name: "小柳酒造", area: create(:area, name: "佐賀県")))
        create(:brand, name: "高砂", brewery: create(:brewery, name: "木屋正酒造", area: create(:area, name: "三重県")))
        stub_gemini(brand_name: "高砂", prefecture: "三重県")
      end

      it "都道府県が一致するものを先頭に並べる" do
        result = described_class.new(front_image: front_image).call

        expect(result[:brand_match][:candidates].first[:area_name]).to eq("三重県")
      end
    end

    context "同名の銘柄が表示上限を超える場合" do
      before do
        (described_class::CANDIDATES_MAX + 3).times do
          create(:brand, name: "どぶろく", brewery: create(:brewery))
        end
        stub_gemini(brand_name: "どぶろく")
      end

      it "上限件数までに切り詰める" do
        result = described_class.new(front_image: front_image).call

        expect(result[:brand_match][:candidates].size).to eq(described_class::CANDIDATES_MAX)
      end
    end

    context "銘柄がマスタになく、蔵元は法人格を除くと部分一致する場合" do
      let!(:brewery) { create(:brewery, name: "山本", area: create(:area, name: "秋田県")) }

      before do
        stub_gemini(brand_name: "未知の銘柄", product_name: "ピュアブラック",
                    brewery_name: "山本酒造店", brewery_name_raw: "株式会社山本酒造店", prefecture: "秋田県")
      end

      it "brand_match は none になる" do
        result = described_class.new(front_image: front_image).call

        expect(result[:brand_match][:status]).to eq("none")
      end

      it "brewery_match は部分一致で single になる" do
        result = described_class.new(front_image: front_image).call

        expect(result[:brewery_match][:status]).to eq("single")
        expect(result[:brewery_match][:candidates].first[:id]).to eq(brewery.id)
      end
    end

    context "同名の蔵元が複数の都道府県にある場合" do
      before do
        create(:brewery, name: "吉田酒造", area: create(:area, name: "滋賀県"))
        create(:brewery, name: "吉田酒造", area: create(:area, name: "福井県"))
        create(:brewery, name: "吉田酒造", area: create(:area, name: "石川県"))
        stub_gemini(brand_name: "未知の銘柄", brewery_name: "吉田酒造", prefecture: "福井県")
      end


      it "候補を減らさず、都道府県が一致するものを先頭に並べる" do
        result = described_class.new(front_image: front_image).call

        candidates = result[:brewery_match][:candidates]
        expect(result[:brewery_match][:status]).to eq("multiple")
        expect(candidates.size).to eq(3)
        expect(candidates.first[:area_name]).to eq("福井県")
      end
    end

    context "brewery_name は誤読だが、原文(raw)側なら部分一致する場合" do
      let!(:brewery) { create(:brewery, name: "山本", area: create(:area, name: "秋田県")) }

      before do
        # brewery_name（AIが法人格を除いた形）は誤読、raw だけが正しいケース
        stub_gemini(brand_name: "未知の銘柄",
                    brewery_name: "山木", brewery_name_raw: "株式会社山本酒造店", prefecture: "秋田県")
      end

      it "原文側の名前でも部分一致を試すのでヒットする" do
        result = described_class.new(front_image: front_image).call

        expect(result[:brewery_match][:candidates].map { |c| c[:id] }).to include(brewery.id)
      end
    end

    context "抽出値に表記揺れがある場合" do
      let!(:brand) do
        create(:brand, name: "No.6",
               brewery: create(:brewery, name: "新政酒造", area: create(:area, name: "秋田県")))
      end

      before do
        # 正規化して照合できること
        stub_gemini(brand_name: "　Ｎｏ．６　")
      end

      it "正規化してからマスタと照合する" do
        result = described_class.new(front_image: front_image).call

        expect(result[:extraction][:brand_name]).to eq("No.6")
        expect(result[:brand_match][:status]).to eq("single")
      end
    end

    context "商品名の別候補が上限を超えて返ってきた場合" do
      before do
        stub_gemini(brand_name: "屋守",
                    product_name_alternatives: [ "候補1", "候補2", "候補3", "候補4", "候補5" ])
      end

      it "上限件数に切り詰める" do
        result = described_class.new(front_image: front_image).call

        expect(result[:extraction][:product_name_alternatives]).to eq(%w[候補1 候補2 候補3])
      end
    end

    context "全項目が読み取れなかった場合" do
      before do
        stub_gemini(confidence: "low")
      end

      it "照合はすべて none / nil になる" do
        result = described_class.new(front_image: front_image).call

        expect(result[:extraction][:brand_name]).to be_nil
        expect(result[:brand_match][:status]).to eq("none")
        expect(result[:brewery_match][:status]).to eq("none")
        expect(result[:area]).to be_nil
      end
    end
  end

  describe "画像に付ける説明文" do
    # GeminiClient へ渡された images を取り出す
    #
    # 戻り値は normalize_extraction を通るだけなので、最低限の1項目でよい。
    #
    # @param extractor [LabelExtraction::Extractor]
    # @return [Array<Hash>] 渡された images（:caption, :mime_type, :data）
    def images_passed_to_client(extractor)
      passed = nil
      allow(LabelExtraction::GeminiClient).to receive(:generate_with_fallback) do |prompt:, images:, response_schema:|
        passed = images
        { brand_name: "屋守" }
      end
      extractor.call

      passed
    end

    it "表ラベルだけのときは表ラベルとして渡す" do
      images = images_passed_to_client(described_class.new(front_image: front_image))

      expect(images).to eq([ { caption: "次の画像は表ラベルです。", mime_type: "image/jpeg", data: "front-binary" } ])
    end

    it "裏ラベルだけのときは裏ラベルとして渡す" do
      images = images_passed_to_client(described_class.new(back_image: back_image))

      expect(images).to eq([ { caption: "次の画像は裏ラベルです。", mime_type: "image/jpeg", data: "back-binary" } ])
    end

    it "両方あるときは表→裏の順に、それぞれの説明文を付けて渡す" do
      images = images_passed_to_client(described_class.new(front_image: front_image, back_image: back_image))

      expect(images.pluck(:caption)).to eq([ "次の画像は表ラベルです。", "次の画像は裏ラベルです。" ])
      expect(images.pluck(:data)).to eq([ "front-binary", "back-binary" ])
    end
  end

  describe "#initialize" do
    it "表・裏のどちらも指定しないと ArgumentError を投げる" do
      expect {
        described_class.new
      }.to raise_error(ArgumentError, /どちらか1枚以上/)
    end
  end

  describe "brewery_brands（蔵元の銘柄一覧）" do
    let!(:brewery) { create(:brewery, name: "森酒造場", area: create(:area, name: "長崎県")) }
    let!(:hiran) { create(:brand, name: "飛鸞", brewery: brewery) }
    let!(:philand) { create(:brand, name: "フィランド", brewery: brewery) }

    context "銘柄がマスタになく、蔵元は1件に確定した場合" do
      before do
        # ラベルがローマ字表記で、AIは正しく読んでもマスタと一致しない場合
        stub_gemini(brand_name: "HIRAN", brewery_name: "森酒造場", prefecture: "長崎県")
      end

      it "その蔵元の銘柄を候補として返す" do
        result = described_class.new(front_image: front_image).call

        expect(result[:brand_match][:status]).to eq("none")
        expect(result[:brewery_match][:status]).to eq("single")
        expect(result[:brewery_brands].map { |c| c[:id] }).to contain_exactly(hiran.id, philand.id)
      end
    end

    context "銘柄がマスタで見つかった場合" do
      before do
        stub_gemini(brand_name: "飛鸞", brewery_name: "森酒造場", prefecture: "長崎県")
      end

      it "救済の必要がないので空配列を返す" do
        result = described_class.new(front_image: front_image).call

        expect(result[:brand_match][:status]).to eq("single")
        expect(result[:brewery_brands]).to be_empty
      end
    end

    context "蔵元も特定できなかった場合" do
      before do
        stub_gemini(brand_name: "未知の銘柄", brewery_name: "未知の酒造")
      end

      it "どの蔵元の銘柄を出すか決められないので空配列を返す" do
        result = described_class.new(front_image: front_image).call

        expect(result[:brewery_brands]).to be_empty
      end
    end
  end

  describe "brand_sakes（銘柄の記録済み商品名）" do
    let!(:brand) do
      create(:brand, name: "作",
             brewery: create(:brewery, name: "清水清三郎商店", area: create(:area, name: "三重県")))
    end

    context "銘柄が1件に確定し、その銘柄に商品が記録済みの場合" do
      let!(:sake) { create(:sake, brand: brand, product_name: "恵乃智") }

      before { stub_gemini(brand_name: "作", product_name: "純米吟醸 恵乃智") }

      it "選択に必要な sake_id を付けて返す" do
        result = described_class.new(front_image: front_image).call

        expect(result[:brand_match][:status]).to eq("single")
        candidate = result[:brand_sakes].first
        expect(candidate[:sake_id]).to eq(sake.id)
        expect(candidate[:product_name]).to eq("恵乃智")
        expect(candidate[:label]).to eq("恵乃智（吟ログに記録あり）")
      end
    end

    context "記録済みの商品が複数ある場合" do
      before do
        create(:sake, brand: brand, product_name: "雅乃智")
        create(:sake, brand: brand, product_name: "純米吟醸 恵乃智")
        create(:sake, brand: brand, product_name: "恵乃智")
        stub_gemini(brand_name: "作", product_name: "恵乃智")
      end

      it "AIが読んだ商品名に近い順（完全一致→部分一致→その他）に並べる" do
        result = described_class.new(front_image: front_image).call

        expect(result[:brand_sakes].map { |c| c[:product_name] })
          .to eq([ "恵乃智", "純米吟醸 恵乃智", "雅乃智" ])
      end
    end

    context "記録済みの商品が表示上限を超える場合" do
      before do
        (described_class::CANDIDATES_MAX + 3).times do |index|
          create(:sake, brand: brand, product_name: "商品#{index}")
        end
        stub_gemini(brand_name: "作", product_name: "恵乃智")
      end

      it "上限件数までに切り詰める" do
        result = described_class.new(front_image: front_image).call

        expect(result[:brand_sakes].size).to eq(described_class::CANDIDATES_MAX)
      end
    end

    context "銘柄は確定したが、商品名を読み取れなかった場合" do
      before do
        create(:sake, brand: brand, product_name: "雅乃智")
        create(:sake, brand: brand, product_name: "恵乃智")
        stub_gemini(brand_name: "作", product_name: nil)
      end

      it "並べ替えの手がかりが無くても、記録済みの商品名は候補として返す" do
        result = described_class.new(front_image: front_image).call

        expect(result[:extraction][:product_name]).to be_nil
        expect(result[:brand_sakes].pluck(:product_name)).to contain_exactly("恵乃智", "雅乃智")
      end
    end

    context "銘柄に商品がまだ記録されていない場合" do
      before { stub_gemini(brand_name: "作", product_name: "恵乃智") }

      it "見せる候補がないので空配列を返す" do
        result = described_class.new(front_image: front_image).call

        expect(result[:brand_sakes]).to be_empty
      end
    end

    context "同名の銘柄が複数あり、1件に絞れなかった場合" do
      before do
        create(:brand, name: "作", brewery: create(:brewery, name: "別の酒造"))
        create(:sake, brand: brand, product_name: "恵乃智")
        stub_gemini(brand_name: "作", product_name: "恵乃智")
      end

      it "どの銘柄の商品を出すか決められないので空配列を返す" do
        result = described_class.new(front_image: front_image).call

        expect(result[:brand_match][:status]).to eq("multiple")
        expect(result[:brand_sakes]).to be_empty
      end
    end
  end
end
