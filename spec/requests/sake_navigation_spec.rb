require 'rails_helper'

# タイムライン・検索結果・マイログ・日本酒詳細・記録詳細の各画面から、
# 日本酒詳細・検索結果へ移動するリンクのテスト。
# 見た目ではなく「リンクが存在するか」だけを URL で検証する
RSpec.describe "日本酒の導線", type: :request do
  let(:user) { create(:user) }
  let(:sake) { create(:sake) }
  let!(:sake_log) { create(:sake_log, sake: sake, user: user) }

  describe "日本酒詳細への導線（商品名リンク）" do
    it "タイムラインのカードに詳細へのリンクがある" do
      get timeline_path

      expect(response.body).to include sake_path(sake)
    end

    it "記録詳細に詳細へのリンクがある" do
      get sake_log_path(sake_log)

      expect(response.body).to include sake_path(sake)
    end

    it "マイログ一覧のカードに詳細へのリンクがある" do
      sign_in user
      get sake_logs_path

      expect(response.body).to include sake_path(sake)
    end
  end

  describe "検索結果への導線（銘柄・蔵元・都道府県のリンク）" do
    let(:filter_paths) do
      brewery = sake.brand.brewery
      [ sakes_path(brand_id: sake.brand_id), sakes_path(brewery_id: brewery.id), sakes_path(area_id: brewery.area_id) ]
    end

    it "タイムラインのカードにある" do
      get timeline_path

      expect(response.body).to include(*filter_paths)
    end

    it "検索結果の行にある" do
      get sakes_path

      expect(response.body).to include(*filter_paths)
    end

    it "マイログ一覧のカードにある" do
      sign_in user
      get sake_logs_path

      expect(response.body).to include(*filter_paths)
    end

    it "日本酒詳細にある" do
      get sake_path(sake)

      expect(response.body).to include(*filter_paths)
    end

    it "記録詳細にある" do
      get sake_log_path(sake_log)

      expect(response.body).to include(*filter_paths)
    end
  end
end
