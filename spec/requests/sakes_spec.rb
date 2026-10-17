require 'rails_helper'

RSpec.describe "Sakes", type: :request do
  let(:sake) { create(:sake) }

  # どの日本酒がヒットするかの細かい条件は spec/models/sake_spec.rb で検証する
  describe "GET /sakes" do
    let!(:sake) { create(:sake, product_name: "純米吟醸", brand: create(:brand, name: "AKABU")) }

    it "未ログインでも 200 が返る" do
      get sakes_path

      expect(response).to have_http_status(:ok)
    end

    it "キーワード未入力なら、一覧を出さずに入力を促す" do
      get sakes_path

      expect(response.body).to include I18n.t("sakes.index.prompt")
      expect(response.body).not_to include sake_path(sake)
    end

    it "空白だけのキーワードは未入力として扱う" do
      get sakes_path(keyword: "　")

      expect(response.body).to include I18n.t("sakes.index.prompt")
    end

    it "ヒットした日本酒の情報と、詳細へのリンクが出る" do
      get sakes_path(keyword: "AKABU")

      expect(response.body).to include sake_path(sake)
      expect(response.body).to include "AKABU", "純米吟醸", sake.brand.brewery.name, sake.brand.brewery.area.name
    end

    it "ヒットしなければ、見つからなかった旨を出す" do
      get sakes_path(keyword: "存在しない銘柄")

      expect(response.body).to include I18n.t("sakes.index.not_found", keyword: "存在しない銘柄")
      expect(response.body).not_to include sake_path(sake)
    end

    it "検索後もキーワードが入力欄に残る" do
      get sakes_path(keyword: "AKABU")

      expect(response.body).to include 'value="AKABU"'
    end

    # 集計前は average_rating が nil。ビューの分岐が壊れると nil.round で 500 になる
    it "集計済みの日本酒があってもエラーにならない" do
      create(:sake_log, sake: sake)
      sake.refresh_aggregation!

      get sakes_path(keyword: "AKABU")

      expect(response).to have_http_status(:ok)
    end

    it "結果が1ページ分を超えると、キーワードを引き継いだ次ページの Turbo Frame が出る" do
      # let! で1件作っているので、10件足して合計11件（2ページ）にする
      create_list(:sake, 10, brand: sake.brand)

      get sakes_path(keyword: "AKABU")

      # ERB は & を &amp; に変換して出力するため、同じ変換をかけてから比べる
      expect(response.body).to include ERB::Util.html_escape(sakes_path(keyword: "AKABU", page: 2))
    end

    # Turbo は、リクエスト元と同じ id の Frame が返ってこないと "Content missing" を表示する
    it "Turbo Frame からの要求には、同じ id の Frame で2ページ目を返す" do
      create_list(:sake, 10, brand: sake.brand)

      get sakes_path(keyword: "AKABU", page: 2), headers: { "Turbo-Frame" => "sakes_page_2" }

      expect(response.body).to include 'id="sakes_page_2"'
    end
  end

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
