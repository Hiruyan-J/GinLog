require 'rails_helper'

# == Schema Information
#
# Table name: sakes
#
#  id           :bigint           not null, primary key
#  product_name :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  brand_id     :bigint           not null
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
end
