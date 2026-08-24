require 'rails_helper'

RSpec.describe SakeAggregationJob, type: :job do
  describe "#perform" do
    let(:sake) { create(:sake) }

    it "sake の集計値を再計算して保存する" do
      create(:sake_log, sake: sake, rating: 4, taste_strength: 2.0, aroma_strength: 8.0)

      described_class.perform_now(sake.id)

      sake.reload
      expect(sake.sake_logs_count).to eq 1
      expect(sake.average_rating).to eq 4.0
      expect(sake.average_taste_strength).to eq 2.0
      expect(sake.average_aroma_strength).to eq 8.0
    end

    it "投稿が0件の sake は削除する" do
      described_class.perform_now(sake.id)

      expect(Sake.exists?(sake.id)).to be false
    end

    it "投稿がある sake は削除しない" do
      create(:sake_log, sake: sake)

      described_class.perform_now(sake.id)

      expect(Sake.exists?(sake.id)).to be true
    end

    it "sake が既に削除されていても例外にならない" do
      missing_id = sake.id
      sake.destroy!

      expect { described_class.perform_now(missing_id) }.not_to raise_error
    end
  end
end
