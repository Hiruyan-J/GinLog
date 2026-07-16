require 'rails_helper'

RSpec.describe Brewery, type: :model do
  describe "バリデーション" do
    subject { build(:brewery) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(Brewery::NAME_MAX_LENGTH) }

    describe "sakenowa_id の一意性(allow_nil)" do
      # validate_uniqueness_of は「既存レコード」が必要なため create で永続化する
      subject { create(:brewery, sakenowa_id: 1) }

      it { is_expected.to validate_uniqueness_of(:sakenowa_id).allow_nil }
    end
  end

  describe "アソシエーション" do
    it { is_expected.to belong_to(:area) }
    it { is_expected.to have_many(:brands).dependent(:restrict_with_exception) }
  end

  describe "正規化(normalizes_text :name)" do
    it "全角スペース・連続空白を正規化して代入する" do
      full_width_space = "　" # 全角スペース
      brewery = build(:brewery, name: "#{full_width_space}新政#{full_width_space}#{full_width_space}酒造#{full_width_space}")

      expect(brewery.name).to eq "新政 酒造"
    end
  end

  describe ".active スコープ" do
    it "is_deleted: false のレコードだけを返す" do
      active_brewery = create(:brewery, is_deleted: false)
      deleted_brewery = create(:brewery, is_deleted: true)

      expect(Brewery.active).to include(active_brewery)
      expect(Brewery.active).not_to include(deleted_brewery)
    end
  end

  describe ".search_by_name スコープ" do
    it "名前の部分一致で active なレコードを返す" do
      matched = create(:brewery, name: "新政酒造")
      unmatched = create(:brewery, name: "獺祭酒造")

      result = Brewery.search_by_name("新政")

      expect(result).to include(matched)
      expect(result).not_to include(unmatched)
    end

    it "is_deleted のレコードは除外する" do
      deleted = create(:brewery, name: "新政酒造", is_deleted: true)

      expect(Brewery.search_by_name("新政")).not_to include(deleted)
    end

    it "空文字なら none を返す" do
      create(:brewery, name: "新政酒造")

      expect(Brewery.search_by_name("")).to be_empty
    end

    it "最大10件までに制限する" do
      11.times { |i| create(:brewery, name: "検索酒造#{i}") }

      expect(Brewery.search_by_name("検索酒造").size).to eq 10
    end
  end
end
