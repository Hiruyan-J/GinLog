require 'rails_helper'

RSpec.describe TasteAromaQuadrant do
  describe ".key_for" do
    it "香り・味の値から象限キーを返す" do
      expect(described_class.key_for(aroma_strength: 8.0, taste_strength: 3.0)).to eq "aroma_high_taste_light"
      expect(described_class.key_for(aroma_strength: 8.0, taste_strength: 8.0)).to eq "aroma_high_taste_strong"
      expect(described_class.key_for(aroma_strength: 2.0, taste_strength: 3.0)).to eq "aroma_low_taste_light"
      expect(described_class.key_for(aroma_strength: 2.0, taste_strength: 8.0)).to eq "aroma_low_taste_strong"
    end

    it "境界値ちょうど（5.0）は右（味が濃い）・上（香りが華やか）に入る" do
      expect(described_class.key_for(aroma_strength: 5.0, taste_strength: 5.0)).to eq "aroma_high_taste_strong"
      expect(described_class.key_for(aroma_strength: 4.9, taste_strength: 4.9)).to eq "aroma_low_taste_light"
    end
  end

  describe ".condition" do
    # sakes の平均値でも sake_logs の記録値でも、同じルールで絞り込めることを確かめる
    it "渡したカラムで、その象限に入る行だけを絞り込める" do
      table = SakeLog.arel_table
      in_quadrant = create(:sake_log, taste_strength: 4.9, aroma_strength: 5.0)
      create(:sake_log, taste_strength: 5.0, aroma_strength: 5.0) # 右上（味が濃い）
      condition = described_class.condition("aroma_high_taste_light", aroma_column: table[:aroma_strength], taste_column: table[:taste_strength])

      expect(SakeLog.where(condition)).to contain_exactly(in_quadrant)
    end

    it "決まったキー以外は KeyError になる" do
      table = Sake.arel_table

      expect {
        described_class.condition("unknown", aroma_column: table[:average_aroma_strength], taste_column: table[:average_taste_strength])
      }.to raise_error(KeyError)
    end
  end
end
