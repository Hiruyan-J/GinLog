require 'rails_helper'

RSpec.describe SakeLog, type: :model do
  describe "バリデーション" do
    subject { build(:sake_log) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:rating) }
    it { is_expected.to validate_presence_of(:taste_strength) }
    it { is_expected.to validate_presence_of(:aroma_strength) }

    it "rating は下限・上限の境界内かつ整数のみ有効" do
      is_expected.to validate_numericality_of(:rating)
        .only_integer
        .is_greater_than_or_equal_to(SakeLog::RATING_MIN)
        .is_less_than_or_equal_to(SakeLog::RATING_MAX)
    end

    it "taste_strength は下限・上限の境界内のみ有効" do
      is_expected.to validate_numericality_of(:taste_strength)
        .is_greater_than_or_equal_to(SakeLog::TASTE_STRENGTH_MIN)
        .is_less_than_or_equal_to(SakeLog::TASTE_STRENGTH_MAX)
    end

    it "aroma_strength は下限・上限の境界内のみ有効" do
      is_expected.to validate_numericality_of(:aroma_strength)
        .is_greater_than_or_equal_to(SakeLog::AROMA_STRENGTH_MIN)
        .is_less_than_or_equal_to(SakeLog::AROMA_STRENGTH_MAX)
    end

    describe "review の文字数" do
      it { is_expected.to validate_length_of(:review).is_at_most(SakeLog::REVIEW_MAX_LENGTH) }

      it "空でも有効(任意項目)" do
        expect(build(:sake_log, review: "")).to be_valid
      end
    end
  end

  describe "アソシエーション" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:sake) }
  end

  describe "reviewの正規化" do
    it "前後の空白を除去して代入する" do
      sake_log = build(:sake_log, review: "  余韻が長い  ")

      expect(sake_log.review).to eq "余韻が長い"
    end
  end
end
