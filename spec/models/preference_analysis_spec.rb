require 'rails_helper'

RSpec.describe PreferenceAnalysis do
  let(:user) { create(:user) }
  let(:niigata) { create(:area, name: "新潟県") }
  let(:analysis) { described_class.new(user) }

  # 指定した都道府県の日本酒に、user の記録を1件作る
  # @param rating [Integer] 好み度
  # @param taste [Float] 味の濃淡
  # @param aroma [Float] 香りの濃淡
  # @param area [Area] 日本酒の蔵元がある都道府県
  # @return [SakeLog]
  def create_log(rating:, taste: 5.0, aroma: 5.0, area: niigata)
    sake = create(:sake, brand: create(:brand, brewery: create(:brewery, area: area)))
    create(:sake_log, user: user, sake: sake, rating: rating, taste_strength: taste, aroma_strength: aroma)
  end

  describe "#any_logs?" do
    it "記録がなければ false、あれば true を返す" do
      expect(analysis.any_logs?).to be false

      create_log(rating: 3)

      expect(described_class.new(user).any_logs?).to be true
    end
  end

  describe "#quadrant_stats" do
    it "象限ごとの平均好み度と件数を返し、記録のない象限は含めない" do
      create_log(rating: 4, taste: 3.0, aroma: 8.0) # 左上
      create_log(rating: 5, taste: 2.0, aroma: 6.0) # 左上
      create_log(rating: 2, taste: 7.0, aroma: 2.0) # 右下

      expect(analysis.quadrant_stats).to eq(
        "aroma_high_taste_light" => PreferenceAnalysis::Stat.new(average: 4.5, count: 2),
        "aroma_low_taste_strong" => PreferenceAnalysis::Stat.new(average: 2.0, count: 1)
      )
    end

    it "境界値ちょうど（5.0）の記録は右上に入る" do
      create_log(rating: 3, taste: 5.0, aroma: 5.0)

      expect(analysis.quadrant_stats.keys).to eq [ "aroma_high_taste_strong" ]
    end

    it "他のユーザーの記録は含めない" do
      create(:sake_log, rating: 5, taste_strength: 3.0, aroma_strength: 8.0)

      expect(analysis.quadrant_stats).to be_empty
    end
  end

  describe "#best_quadrant" do
    it "平均好み度が一番高い象限を返す" do
      create_log(rating: 3, taste: 3.0, aroma: 8.0) # 左上
      create_log(rating: 5, taste: 3.0, aroma: 2.0) # 左下

      expect(analysis.best_quadrant).to eq "aroma_low_taste_light"
    end

    it "平均が同じなら、件数が多い象限を返す" do
      create_log(rating: 4, taste: 3.0, aroma: 8.0) # 左上（1件）
      create_log(rating: 4, taste: 3.0, aroma: 2.0) # 左下（2件）
      create_log(rating: 4, taste: 3.0, aroma: 2.0)

      expect(analysis.best_quadrant).to eq "aroma_low_taste_light"
    end

    it "平均も件数も同じなら、左上 → 右上 → 左下 → 右下 の順で先の象限を返す" do
      create_log(rating: 4, taste: 8.0, aroma: 2.0) # 右下
      create_log(rating: 4, taste: 8.0, aroma: 8.0) # 右上

      expect(analysis.best_quadrant).to eq "aroma_high_taste_strong"
    end

    it "記録がなければ nil を返す" do
      expect(analysis.best_quadrant).to be_nil
    end
  end

  describe "#area_stats" do
    it "都道府県ごとの平均好み度と件数を返し、「その他」は含めない" do
      other = create(:area, name: "その他", sakenowa_id: Area::OTHER_SAKENOWA_ID)
      create_log(rating: 4, area: niigata)
      create_log(rating: 2, area: niigata)
      create_log(rating: 5, area: other)

      expect(analysis.area_stats).to eq(niigata.id => PreferenceAnalysis::Stat.new(average: 3.0, count: 2))
    end
  end

  describe "#best_area" do
    let(:iwate) { create(:area, name: "岩手県") }

    it "平均好み度が一番高い都道府県を返す" do
      create_log(rating: 3, area: niigata)
      create_log(rating: 5, area: iwate)

      expect(analysis.best_area).to eq iwate
    end

    it "平均が同じなら、件数が多い都道府県を返す" do
      create_log(rating: 4, area: iwate)
      create_log(rating: 4, area: niigata)
      create_log(rating: 4, area: niigata)

      expect(analysis.best_area).to eq niigata
    end

    it "平均も件数も同じなら、ID が小さい（北の）都道府県を返す" do
      north, south = [ niigata, iwate ].sort_by(&:id)
      create_log(rating: 4, area: south)
      create_log(rating: 4, area: north)

      expect(analysis.best_area).to eq north
    end

    it "記録がなければ nil を返す" do
      expect(analysis.best_area).to be_nil
    end
  end
end
