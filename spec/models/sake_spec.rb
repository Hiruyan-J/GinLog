require 'rails_helper'

# == Schema Information
#
# Table name: sakes
#
#  id                                                              :bigint           not null, primary key
#  average_aroma_strength(香りの濃淡の平均。未集計・投稿0件は nil) :float
#  average_rating(好み度の平均。未集計・投稿0件は nil)             :float
#  average_taste_strength(味の濃淡の平均。未集計・投稿0件は nil)   :float
#  product_name                                                    :string           not null
#  sake_logs_count(投稿件数。未集計でも0でよいため not null)       :integer          default(0), not null
#  created_at                                                      :datetime         not null
#  updated_at                                                      :datetime         not null
#  brand_id                                                        :bigint           not null
#
# Indexes
#
#  index_sakes_on_brand_id                   (brand_id)
#  index_sakes_on_brand_id_and_product_name  (brand_id,product_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (brand_id => brands.id)
#
RSpec.describe Sake, type: :model do
  describe "バリデーション" do
    subject { build(:sake) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:product_name) }
    it { is_expected.to validate_length_of(:product_name).is_at_most(Sake::PRODUCT_NAME_MAX_LENGTH) }

    describe "product_name の一意性(brand_id スコープ)" do
      # validate_uniqueness_of は「既存レコード」が必要なため create で永続化する
      subject { create(:sake, product_name: "AKABU 純米酒") } # テストするproduct_nameには英字を含めること

      it { is_expected.to validate_uniqueness_of(:product_name).scoped_to(:brand_id) }
    end

    it "別の銘柄なら同じ商品名でも登録できる" do
      create(:sake, product_name: "純米大吟醸", brand: create(:brand))
      other = build(:sake, product_name: "純米大吟醸", brand: create(:brand))

      expect(other).to be_valid
    end
  end

  describe "アソシエーション" do
    it { is_expected.to belong_to(:brand) }
    it { is_expected.to have_many(:sake_logs) }
  end

  describe "正規化(normalizes_text :product_name)" do
    it "全角スペース・連続空白を正規化して代入する" do
      full_width_space = "　" # 全角スペース
      sake = build(:sake, product_name: "#{full_width_space}純米#{full_width_space}#{full_width_space}大吟醸#{full_width_space}")

      expect(sake.product_name).to eq "純米 大吟醸"
    end
  end

  describe ".search_by_product_name スコープ" do
    let(:brand) { create(:brand) }

    it "指定した銘柄内で商品名の部分一致を返す" do
      matched = create(:sake, brand: brand, product_name: "純米大吟醸")
      unmatched = create(:sake, brand: brand, product_name: "本醸造")

      result = Sake.search_by_product_name(brand.id, "大吟醸")

      expect(result).to include(matched)
      expect(result).not_to include(unmatched)
    end

    it "別の銘柄の商品は含まない" do
      other_brand = create(:brand)
      other_sake = create(:sake, brand: other_brand, product_name: "純米大吟醸")

      result = Sake.search_by_product_name(brand.id, "大吟醸")

      expect(result).not_to include(other_sake)
    end

    it "空文字なら none を返す" do
      create(:sake, brand: brand, product_name: "純米大吟醸")

      expect(Sake.search_by_product_name(brand.id, "")).to be_empty
    end
  end

  describe ".spaceless_key" do
    it "半角スペースを取り除く" do
      expect(Sake.spaceless_key("純米中取り 無調整生")).to eq "純米中取り無調整生"
    end

    it "全角スペースも取り除く(NFKCで半角に揃えてから消すため)" do
      expect(Sake.spaceless_key("純米中取り　無調整生")).to eq "純米中取り無調整生"
    end

    it "nil は空文字を返す" do
      expect(Sake.spaceless_key(nil)).to eq ""
    end
  end

  describe ".find_or_initialize_by_product_name" do
    let(:brand) { create(:brand) }
    let!(:existing) { create(:sake, brand: brand, product_name: "純米中取り無調整生") }

    it "完全一致なら既存レコードを返す" do
      result = Sake.find_or_initialize_by_product_name(brand.id, "純米中取り無調整生")

      expect(result).to eq existing
    end

    it "空白の有無だけが違う商品名でも既存レコードを返す" do
      result = Sake.find_or_initialize_by_product_name(brand.id, "純米中取り 無調整生")

      expect(result).to eq existing
    end

    it "全角スペースでも既存レコードを返す" do
      result = Sake.find_or_initialize_by_product_name(brand.id, "純米中取り　無調整生")

      expect(result).to eq existing
    end

    # 「久保田 千寿」と「久保田 千寿 秋あがり」のように、部分一致でも
    # 別商品であるケースが実在するため、部分一致では寄せない
    it "単語が多い場合は、別商品として新規作成の Sake を返す" do
      result = Sake.find_or_initialize_by_product_name(brand.id, "純米中取り無調整生 ひやおろし")

      expect(result).not_to be_persisted
      expect(result.product_name).to eq "純米中取り無調整生 ひやおろし"
    end

    it "単語が少ない場合も別商品として新規の Sake を返す" do
      result = Sake.find_or_initialize_by_product_name(brand.id, "純米中取り")

      expect(result).not_to be_persisted
      expect(result.product_name).to eq "純米中取り"
    end

    it "別の銘柄には紐づかない" do
      other_brand = create(:brand)

      result = Sake.find_or_initialize_by_product_name(other_brand.id, "純米中取り無調整生")

      expect(result).not_to be_persisted
      expect(result.brand_id).to eq other_brand.id
    end
  end

  describe "#refresh_aggregation!" do
    let(:sake) { create(:sake) }

    it "紐づく記録の平均値と件数を保存する" do
      create(:sake_log, sake: sake, rating: 2, taste_strength: 3.0, aroma_strength: 6.0)
      create(:sake_log, sake: sake, rating: 5, taste_strength: 4.0, aroma_strength: 7.0)

      sake.refresh_aggregation!

      expect(sake.sake_logs_count).to eq 2
      expect(sake.average_rating).to eq 3.5
      expect(sake.average_taste_strength).to eq 3.5
      expect(sake.average_aroma_strength).to eq 6.5
    end

    it "平均は小数第2位に丸めて保存する" do
      create(:sake_log, sake: sake, rating: 1)
      create(:sake_log, sake: sake, rating: 1)
      create(:sake_log, sake: sake, rating: 2)

      sake.refresh_aggregation!

      expect(sake.average_rating).to eq 1.33 # 4 ÷ 3 = 1.333... → 1.33
    end

    it "投稿が0件なら件数0・平均nilで保存する" do
      sake.refresh_aggregation!

      expect(sake.sake_logs_count).to eq 0
      expect(sake.average_rating).to be_nil
      expect(sake.average_taste_strength).to be_nil
      expect(sake.average_aroma_strength).to be_nil
    end
  end

  describe ".search_by_keyword" do
    let(:akabu_brewery) { create(:brewery, name: "赤武酒造", area: create(:area, name: "岩手県")) }
    let(:denshu_brewery) { create(:brewery, name: "西田酒造店", area: create(:area, name: "青森県")) }
    let!(:akabu) { create(:sake, product_name: "純米吟醸", brand: create(:brand, name: "AKABU", brewery: akabu_brewery)) }
    let!(:denshu) { create(:sake, product_name: "特別純米酒", brand: create(:brand, name: "田酒", brewery: denshu_brewery)) }

    it "商品名に部分一致する日本酒を返す" do
      expect(Sake.search_by_keyword("吟醸")).to contain_exactly(akabu)
    end

    it "銘柄名に部分一致する日本酒を返す" do
      expect(Sake.search_by_keyword("田酒")).to contain_exactly(denshu)
    end

    it "蔵元名に部分一致する日本酒を返す" do
      expect(Sake.search_by_keyword("赤武")).to contain_exactly(akabu)
    end

    it "都道府県名に部分一致する日本酒を返す" do
      expect(Sake.search_by_keyword("青森")).to contain_exactly(denshu)
    end

    it "英字の大文字・小文字を区別しない" do
      expect(Sake.search_by_keyword("akabu")).to contain_exactly(akabu)
    end

    it "全角の英字でもヒットする" do
      expect(Sake.search_by_keyword("ＡＫＡＢＵ")).to contain_exactly(akabu)
    end

    context "空白で区切って複数の単語を渡したとき" do
      it "単語が別々のカラムにあっても、すべてを含む日本酒を返す" do
        expect(Sake.search_by_keyword("田酒 特別純米")).to contain_exactly(denshu)
      end

      it "1つでも含まない単語があればヒットしない" do
        expect(Sake.search_by_keyword("田酒 吟醸")).to be_empty
      end

      it "全角スペースで区切っても同じ結果になる" do
        expect(Sake.search_by_keyword("田酒　特別純米")).to contain_exactly(denshu)
      end

      it "上限を超えた分の単語は無視する" do
        words = [ "田酒" ] * Sake::KEYWORD_MAX_WORDS + [ "存在しない単語" ]

        expect(Sake.search_by_keyword(words.join(" "))).to contain_exactly(denshu)
      end
    end

    # エスケープされていないと、% は「何でも一致」になり全件が返ってしまう
    it "% と _ は文字そのものとして検索する" do
      expect(Sake.search_by_keyword("%")).to be_empty
      expect(Sake.search_by_keyword("_")).to be_empty
    end

    context "並び順" do
      # 記録が多い順より、銘柄名の完全一致を優先することを確かめるため、
      # 部分一致しただけの日本酒のほうを記録の多い状態にしておく
      it "銘柄名が検索語と完全一致する日本酒を、部分一致だけの日本酒より先にする" do
        # 蔵元名「西田酒造店」が「田酒」に部分一致する別銘柄
        partial_match = create(:sake, sake_logs_count: 10, brand: create(:brand, name: "喜久泉", brewery: denshu_brewery))

        result = Sake.search_by_keyword("田酒").order(sake_logs_count: :desc)

        expect(result).to eq [ denshu, partial_match ]
      end

      it "大文字・小文字が違っても完全一致として扱う" do
        partial_match = create(:sake, product_name: "AKABU 風", sake_logs_count: 10)

        result = Sake.search_by_keyword("akabu").order(sake_logs_count: :desc)

        expect(result).to eq [ akabu, partial_match ]
      end

      it "複数の単語のうち、どれか1つが銘柄名と完全一致すれば先にする" do
        partial_match = create(:sake, product_name: "特別純米酒", sake_logs_count: 10,
                                      brand: create(:brand, name: "喜久泉", brewery: denshu_brewery))

        result = Sake.search_by_keyword("田酒 特別純米").order(sake_logs_count: :desc)

        expect(result).to eq [ denshu, partial_match ]
      end
    end

    it "キーワードが空なら、絞り込まずに全件を返す" do
      expect(Sake.search_by_keyword(nil)).to contain_exactly(akabu, denshu)
      expect(Sake.search_by_keyword("")).to contain_exactly(akabu, denshu)
      expect(Sake.search_by_keyword("　")).to contain_exactly(akabu, denshu)
    end
  end

  describe ".filter_by_ids" do
    let(:iwate) { create(:area, name: "岩手県") }
    let(:akabu_brewery) { create(:brewery, name: "赤武酒造", area: iwate) }
    let(:akabu_brand) { create(:brand, name: "AKABU", brewery: akabu_brewery) }
    let!(:akabu) { create(:sake, product_name: "純米吟醸", brand: akabu_brand) }
    # 同じ蔵元の別銘柄
    let!(:hamamusume) { create(:sake, product_name: "純米酒", brand: create(:brand, name: "浜娘", brewery: akabu_brewery)) }
    # 同じ都道府県の別の蔵元
    let!(:nanbu_bijin) { create(:sake, product_name: "大吟醸", brand: create(:brand, name: "南部美人", brewery: create(:brewery, area: iwate))) }
    # 別の都道府県
    let!(:denshu) { create(:sake, brand: create(:brand, name: "田酒")) }

    it "銘柄で絞り込むと、その銘柄の日本酒だけを返す" do
      expect(Sake.filter_by_ids(brand_id: akabu_brand.id)).to contain_exactly(akabu)
    end

    it "蔵元で絞り込むと、その蔵元の全銘柄の日本酒を返す" do
      expect(Sake.filter_by_ids(brewery_id: akabu_brewery.id)).to contain_exactly(akabu, hamamusume)
    end

    it "都道府県で絞り込むと、その都道府県の全蔵元の日本酒を返す" do
      expect(Sake.filter_by_ids(area_id: iwate.id)).to contain_exactly(akabu, hamamusume, nanbu_bijin)
    end

    it "複数の条件を渡すと、すべてに当てはまる日本酒だけを返す" do
      expect(Sake.filter_by_ids(brewery_id: akabu_brewery.id, area_id: denshu.brand.brewery.area_id)).to be_empty
    end

    it "条件がなければ、絞り込まずに全件を返す" do
      expect(Sake.filter_by_ids).to contain_exactly(akabu, hamamusume, nanbu_bijin, denshu)
    end

    # Ransack の JOIN とサブクエリが衝突しないことを確かめる
    it "フリーワード検索と組み合わせられる" do
      expect(Sake.search_by_keyword("純米").filter_by_ids(area_id: iwate.id)).to contain_exactly(akabu, hamamusume)
    end
  end

  describe ".filter_by_quadrants" do
    # 境界値ちょうど（5.0）は上・右に入ることも、ここで確かめる
    let!(:high_light) { create(:sake, average_aroma_strength: 5.0, average_taste_strength: 4.9) }
    let!(:high_strong) { create(:sake, average_aroma_strength: 8.0, average_taste_strength: 5.0) }
    let!(:low_light) { create(:sake, average_aroma_strength: 2.0, average_taste_strength: 3.0) }
    let!(:low_strong) { create(:sake, average_aroma_strength: 4.9, average_taste_strength: 9.0) }
    # 未集計（平均が nil）
    let!(:not_aggregated) { create(:sake) }

    it "象限を1つ選ぶと、その象限の日本酒だけを返す" do
      expect(Sake.filter_by_quadrants([ "aroma_high_taste_light" ])).to contain_exactly(high_light)
      expect(Sake.filter_by_quadrants([ "aroma_high_taste_strong" ])).to contain_exactly(high_strong)
      expect(Sake.filter_by_quadrants([ "aroma_low_taste_light" ])).to contain_exactly(low_light)
      expect(Sake.filter_by_quadrants([ "aroma_low_taste_strong" ])).to contain_exactly(low_strong)
    end

    it "象限を複数選ぶと、どれかの象限に当てはまる日本酒を返す" do
      expect(Sake.filter_by_quadrants(%w[aroma_high_taste_light aroma_low_taste_strong])).to contain_exactly(high_light, low_strong)
    end

    it "4つとも選んでも、平均が nil の日本酒は含まない" do
      expect(Sake.filter_by_quadrants(TasteAromaQuadrant::KEYS)).not_to include(not_aggregated)
    end

    it "象限がなければ、絞り込まずに全件を返す" do
      expect(Sake.filter_by_quadrants([])).to contain_exactly(high_light, high_strong, low_light, low_strong, not_aggregated)
    end

    it "決まったキー以外の値は無視する" do
      expect(Sake.filter_by_quadrants([ "unknown", "aroma_low_taste_light" ])).to contain_exactly(low_light)
    end

    # Ransack の JOIN と、象限の条件（sakes テーブルのカラム）がぶつからないことを確かめる
    it "フリーワード検索・ID での絞り込みと組み合わせられる" do
      high_light.update!(product_name: "純米吟醸")
      low_light.update!(product_name: "純米酒")

      sakes = Sake.search_by_keyword("純米").filter_by_ids(brand_id: high_light.brand_id).filter_by_quadrants([ "aroma_high_taste_light", "aroma_low_taste_light" ])

      expect(sakes).to contain_exactly(high_light)
    end
  end

  describe "#aggregated?" do
    it "集計済み（average_rating あり）なら true" do
      sake = build(:sake, average_rating: 3.5)

      expect(sake).to be_aggregated
    end

    it "未集計（average_rating が nil）なら false" do
      sake = build(:sake, average_rating: nil)

      expect(sake).not_to be_aggregated
    end
  end
end
