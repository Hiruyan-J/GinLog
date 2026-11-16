require "rails_helper"

RSpec.describe SakesHelper, type: :helper do
  describe "#product_name_link" do
    let(:sake) { create(:sake, product_name: "純米大吟醸 無濾過生原酒") }

    it "商品名を、日本酒詳細へのリンクにする" do
      html = helper.product_name_link(sake)

      expect(html).to include %(href="#{sake_path(sake)}")
      expect(html).to include "純米大吟醸 無濾過生原酒"
    end

    it "商品名の右に「›」アイコンを付ける" do
      expect(helper.product_name_link(sake)).to include "chevron_right"
    end

    it "truncate: true のときだけ、商品名を「…」で省略するクラスを付ける" do
      expect(helper.product_name_link(sake, truncate: true)).to include "truncate"
      expect(helper.product_name_link(sake)).not_to include "truncate"
    end
  end
end
