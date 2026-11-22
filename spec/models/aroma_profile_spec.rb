require "rails_helper"

RSpec.describe AromaProfile, type: :model do
  describe "バリデーション" do
    subject { build(:aroma_profile) }

    it { is_expected.to be_valid }

    it "全項目が記録なし（nil）でも有効" do
      expect(build(:aroma_profile, :blank)).to be_valid
    end

    # 吟醸香・原料香・熟成香のそれぞれ
    AromaProfile::INTENSITY_ATTRIBUTES.each_value do |attribute|
      it "#{attribute} は下限・上限の境界内のみ有効（nil = 記録なしは許可）" do
        is_expected.to validate_numericality_of(attribute)
          .is_greater_than_or_equal_to(AromaProfile::INTENSITY_MIN)
          .is_less_than_or_equal_to(AromaProfile::INTENSITY_MAX)
          .allow_nil
      end
    end

    it "1つの記録に1行まで（sake_log_id に unique index）" do
      is_expected.to have_db_index(:sake_log_id).unique
    end
  end

  describe "アソシエーション" do
    it { is_expected.to belong_to(:sake_log) }
    it { is_expected.to have_many(:aroma_profile_aroma_tags).dependent(:destroy) }
    it { is_expected.to have_many(:aroma_tags).through(:aroma_profile_aroma_tags) }

    # dependent: :destroy の設定だけでなく、実際に消えるもの・残るものを確かめる
    it "記録（SakeLog）を削除すると、香りの詳細と選んだタグのつながりも削除される（タグ自体は残る）" do
      aroma_tag = create(:aroma_tag)
      aroma_profile = create(:aroma_profile, aroma_tags: [ aroma_tag ])

      expect { aroma_profile.sake_log.destroy }
        .to change(AromaProfile, :count).by(-1)
        .and change(AromaProfileAromaTag, :count).by(-1)
        .and change(AromaTag, :count).by(0)
    end
  end

  describe "#recorded?" do
    it "強弱が全部 nil で、タグも無ければ false" do
      expect(build(:aroma_profile, :blank).recorded?).to be false
    end

    it "強弱を 0 と記録していれば true（0 は記録なしと区別する）" do
      expect(build(:aroma_profile, :blank, aged_aroma_intensity: 0).recorded?).to be true
    end

    it "タグを1つ選んだだけでも true" do
      aroma_profile = create(:aroma_profile, :blank, aroma_tags: [ create(:aroma_tag) ])

      expect(aroma_profile.recorded?).to be true
    end
  end

  describe "#aroma_tags_for" do
    it "指定した区分のタグだけを表示順で返す" do
      ginjo_second = create(:aroma_tag, category: :ginjo, position: 2)
      ginjo_first = create(:aroma_tag, category: :ginjo, position: 1)
      aged_tag = create(:aroma_tag, category: :aged, position: 1)
      aroma_profile = create(:aroma_profile, aroma_tags: [ ginjo_second, aged_tag, ginjo_first ])

      expect(aroma_profile.aroma_tags_for("ginjo")).to eq [ ginjo_first, ginjo_second ]
      expect(aroma_profile.aroma_tags_for("ingredient")).to eq []
    end
  end
end
