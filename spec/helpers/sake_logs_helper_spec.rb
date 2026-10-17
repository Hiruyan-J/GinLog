require "rails_helper"

RSpec.describe SakeLogsHelper, type: :helper do
  describe "#lit_half_star_count" do
    it "好み度を 0.5 刻みに四捨五入し、半分の星の個数で返す" do
      expect(helper.lit_half_star_count(3.5)).to eq 7 # 星 3 個半
      expect(helper.lit_half_star_count(3.2)).to eq 6 # 3.0 に丸めて星 3 個
      expect(helper.lit_half_star_count(3.3)).to eq 7 # 3.5 に丸めて星 3 個半
      expect(helper.lit_half_star_count(3.8)).to eq 8 # 4.0 に丸めて星 4 個
    end

    it "最小の 1.0 は 2 個、最大の 5.0 は 10 個になる" do
      expect(helper.lit_half_star_count(1.0)).to eq 2
      expect(helper.lit_half_star_count(5.0)).to eq 10
    end

    it "整数の好み度は、その 2 倍の個数を返す" do
      expect(helper.lit_half_star_count(3)).to eq 6
    end
  end

  describe "#half_star_class" do
    it "偶数番目は左半分、奇数番目は右半分のクラスを返す" do
      expect(helper.half_star_class(0, 7, :sm)).to include "mask-half-1"
      expect(helper.half_star_class(1, 7, :sm)).to include "mask-half-2"
    end

    # lit_count が 7 なら、0〜6 番目の 7 個が点灯する
    it "lit_count 個目までを点灯色、それ以降を消灯色にする" do
      expect(helper.half_star_class(6, 7, :sm)).to include "bg-yellow-300"
      expect(helper.half_star_class(7, 7, :sm)).to include "bg-stone-400"
    end

    it "size に応じた大きさのクラスを返す" do
      expect(helper.half_star_class(0, 7, :sm)).to include SakeLogsHelper::HALF_STAR_SIZES[:sm]
      expect(helper.half_star_class(0, 7, :lg)).to include SakeLogsHelper::HALF_STAR_SIZES[:lg]
    end
  end
end
