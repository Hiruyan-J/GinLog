require 'rails_helper'

RSpec.describe "Sakes", type: :request do
  let(:sake) { create(:sake) }

  describe "GET /sakes/:id" do
    before do
      create(:sake_log, sake: sake)
      # after_commit のジョブはテストでは自動実行されないため、集計だけ直接実行する
      sake.refresh_aggregation!
    end

    it "未ログインでも 200 が返る" do
      get sake_path(sake)

      expect(response).to have_http_status(:ok)
    end

    # 集計前は average_* が nil になる。
    # ビューの分岐（aggregated?）が壊れると nil.round で 500 になるため、
    # 案内の文言ではなくステータスで検証する（文言を変えても壊れない）
    it "未集計でもエラーにならない" do
      sake.update!(average_rating: nil)

      get sake_path(sake)

      expect(response).to have_http_status(:ok)
    end

    it "存在しない ID なら 404 が返る" do
      get sake_path(id: 0)

      expect(response).to have_http_status(:not_found)
    end

    # 次ページの URL で検証するため、無限スクロールを「もっと見る」ボタンに変えても壊れない
    it "記録が1ページ分を超えると、次ページを読み込む Turbo Frame が出る" do
      # before で1件作っているので、10件足して合計11件（2ページ）にする
      create_list(:sake_log, 10, sake: sake)

      get sake_path(sake)

      expect(response.body).to include sake_path(sake, page: 2)
    end
  end

  # 「リンクが存在するか」だけを URL で検証する。
  describe "日本酒詳細への導線（商品名リンク）" do
    let(:user) { create(:user) }
    let!(:sake_log) { create(:sake_log, sake: sake, user: user) }

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
end
