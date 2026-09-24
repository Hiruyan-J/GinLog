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
