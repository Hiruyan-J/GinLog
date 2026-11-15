require "rails_helper"

# == Schema Information
#
# Table name: taste_profiles
#
#  id                                                                   :bigint           not null, primary key
#  acidity_intensity(酸味の強弱(0〜10)。NULL = 記録なし)                :float
#  carbonation(炭酸感 0:無し 1:ガス感 2:微発泡 3:発泡。NULL = 記録なし) :integer
#  finish_intensity(余韻の長さ(0〜10)。NULL = 記録なし)                 :float
#  maturity_intensity(熟成度の強弱(0〜10)。NULL = 記録なし)             :float
#  sweetness_intensity(甘味の強弱(0〜10)。NULL = 記録なし)              :float
#  umami_intensity(旨味の強弱(0〜10)。NULL = 記録なし)                  :float
#  created_at                                                           :datetime         not null
#  updated_at                                                           :datetime         not null
#  sake_log_id                                                          :bigint           not null
#
# Indexes
#
#  index_taste_profiles_on_sake_log_id  (sake_log_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (sake_log_id => sake_logs.id)
#
RSpec.describe TasteProfile, type: :model do
  describe "バリデーション" do
    subject { build(:taste_profile) }

    it { is_expected.to be_valid }

    it "全項目が記録なし（nil）でも有効" do
      expect(build(:taste_profile, :blank)).to be_valid
    end

    # 甘味・旨味・酸味・熟成度・余韻のそれぞれ
    TasteProfile::INTENSITY_SCALES.each_key do |attribute|
      it "#{attribute} は下限・上限の境界内のみ有効（nil = 記録なしは許可）" do
        is_expected.to validate_numericality_of(attribute)
          .is_greater_than_or_equal_to(TasteProfile::INTENSITY_MIN)
          .is_less_than_or_equal_to(TasteProfile::INTENSITY_MAX)
          .allow_nil
      end
    end

    # validating … 想定外の値は例外ではなくバリデーションエラーにする（nil = 記録なしは許可）
    it "carbonation は 無し〜発泡 の4段階の enum" do
      is_expected.to define_enum_for(:carbonation)
        .with_values(still: 0, gassy: 1, slightly_sparkling: 2, sparkling: 3)
        .validating(allowing_nil: true)
    end

    it "1つの記録に1行まで（sake_log_id に unique index）" do
      is_expected.to have_db_index(:sake_log_id).unique
    end
  end

  describe "アソシエーション" do
    it { is_expected.to belong_to(:sake_log) }
  end

  describe "#recorded?" do
    it "全項目が nil なら false" do
      expect(build(:taste_profile, :blank).recorded?).to be false
    end

    it "強弱を 0 と記録していれば true（0 は記録なしと区別する）" do
      expect(build(:taste_profile, :blank, sweetness_intensity: 0).recorded?).to be true
    end

    it "炭酸感「無し」だけを記録していても true" do
      expect(build(:taste_profile, :blank, carbonation: :still).recorded?).to be true
    end
  end
end
