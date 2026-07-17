require 'rails_helper'

RSpec.describe Brand, type: :model do
  describe "バリデーション" do
    subject { build(:brand) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(Brand::NAME_MAX_LENGTH) }

    describe "sakenowa_id の一意性(allow_nil)" do
      # validate_uniqueness_of は「既存レコード」が必要なため create で永続化する
      subject { create(:brand, sakenowa_id: 1) }

      it { is_expected.to validate_uniqueness_of(:sakenowa_id).allow_nil }
    end
  end

  describe "アソシエーション" do
    it { is_expected.to belong_to(:brewery) }
    it { is_expected.to have_many(:sakes) }
  end

  describe "正規化(normalizes_text :name)" do
    it "全角英数字・全角スペースを正規化して代入する" do
      full_width_space = "　" # 全角スペース
      brand = build(:brand, name: "#{full_width_space}ＡＫＡＢＵ#{full_width_space}純米酒#{full_width_space}")

      expect(brand.name).to eq "AKABU 純米酒"
    end
  end

  describe ".active スコープ" do
    it "is_deleted: false のレコードだけを返す" do
      active_brand = create(:brand, is_deleted: false)
      deleted_brand = create(:brand, is_deleted: true)

      expect(Brand.active).to include(active_brand)
      expect(Brand.active).not_to include(deleted_brand)
    end
  end

  describe ".search_by_name スコープ" do
    it "名前の部分一致で active なレコードを返す" do
      matched = create(:brand, name: "赤武")
      unmatched = create(:brand, name: "獺祭")

      result = Brand.search_by_name("赤")

      expect(result).to include(matched)
      expect(result).not_to include(unmatched)
    end

    it "is_deleted のレコードは除外する" do
      deleted = create(:brand, name: "赤武", is_deleted: true)

      expect(Brand.search_by_name("赤")).not_to include(deleted)
    end

    it "空文字なら none を返す" do
      create(:brand, name: "赤武")

      expect(Brand.search_by_name("")).to be_empty
    end

    it "最大10件までに制限する" do
      11.times { |i| create(:brand, name: "検索銘柄#{i}") }

      expect(Brand.search_by_name("検索銘柄").size).to eq 10
    end
  end
end
