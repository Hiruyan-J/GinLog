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

    it "キーワード未入力なら、全件を表示する" do
      other_sake = create(:sake)

      get sakes_path

      expect(response.body).to include sake_path(sake), sake_path(other_sake)
    end

    it "空白だけのキーワードは未入力として扱う" do
      get sakes_path(keyword: "　")

      expect(response.body).to include sake_path(sake)
    end

    it "日本酒が1件もなければ、その旨を出す" do
      sake.destroy!

      get sakes_path

      expect(response.body).to include I18n.t("sakes.index.no_sakes")
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

    # どの日本酒が残るかの細かい条件は spec/models/sake_spec.rb（.filter_by_ids）で検証する
    context "銘柄・蔵元・都道府県で絞り込んだとき" do
      let!(:other_sake) { create(:sake) }

      it "銘柄で絞り込むと、その銘柄の日本酒だけが出る" do
        get sakes_path(brand_id: sake.brand_id)

        expect(response.body).to include sake_path(sake)
        expect(response.body).not_to include sake_path(other_sake)
      end

      it "蔵元で絞り込むと、その蔵元の日本酒だけが出る" do
        get sakes_path(brewery_id: sake.brand.brewery_id)

        expect(response.body).to include sake_path(sake)
        expect(response.body).not_to include sake_path(other_sake)
      end

      it "都道府県で絞り込むと、その都道府県の日本酒だけが出る" do
        get sakes_path(area_id: sake.brand.brewery.area_id)

        expect(response.body).to include sake_path(sake)
        expect(response.body).not_to include sake_path(other_sake)
      end

      it "絞り込み条件の名前が出る" do
        get sakes_path(brand_id: sake.brand_id)

        expect(response.body).to include I18n.t("sakes.filter_conditions.heading"), "銘柄：AKABU"
      end

      it "「解除」リンクは、その条件だけを外してキーワードを引き継ぐ" do
        area_id = sake.brand.brewery.area_id

        get sakes_path(keyword: "純米", brand_id: sake.brand_id, area_id: area_id)

        expect(response.body).to include ERB::Util.html_escape(sakes_path(keyword: "純米", area_id: area_id))
      end

      it "絞り込み条件が、検索フォームの hidden フィールドに入る（フリーワード検索で引き継ぐ）" do
        get sakes_path(brand_id: sake.brand_id)

        expect(response.body).to include %(value="#{sake.brand_id}" type="hidden" name="brand_id")
      end

      it "次ページの Turbo Frame に、絞り込み条件を引き継ぐ" do
        create_list(:sake, 10, brand: sake.brand)

        get sakes_path(brand_id: sake.brand_id)

        # キーワード未入力でも、次ページの URL には空の keyword が付く（既存の動き）
        expect(response.body).to include ERB::Util.html_escape(sakes_path(keyword: "", page: 2, brand_id: sake.brand_id))
      end

      it "存在しない ID は無視して、絞り込まずに表示する" do
        get sakes_path(brand_id: 0)

        expect(response.body).to include sake_path(sake), sake_path(other_sake)
        expect(response.body).not_to include I18n.t("sakes.filter_conditions.heading")
      end

      it "絞り込みだけで1件もなければ、その旨を出す" do
        brand_without_sakes = create(:brand)

        get sakes_path(brand_id: brand_without_sakes.id)

        expect(response.body).to include I18n.t("sakes.index.filtered_not_found")
      end
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
end
