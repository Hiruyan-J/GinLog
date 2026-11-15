require 'rails_helper'

RSpec.describe "SakeLogs", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /sake_logs/:id" do
    it "from 付きでアクセスしても、canonical と og:url は from なしの URL になる" do
      sake_log = create(:sake_log, user: user)

      get sake_log_path(sake_log, from: "timeline")

      html = Nokogiri::HTML(response.body)
      expect(html.at_css('link[rel="canonical"]')["href"]).to eq sake_log_url(sake_log)
      expect(html.at_css('meta[property="og:url"]')["content"]).to eq sake_log_url(sake_log)
    end

    # 味わいの詳細の表示
    context "味わいの詳細" do
      let(:sake_log) { create(:sake_log, user: user) }

      it "全項目を表示し、記録した項目は値とバー、記録なしの項目は「記録なし」と表示される" do
        create(:taste_profile, :blank, sake_log: sake_log, sweetness_intensity: 0, carbonation: :still)

        get sake_log_path(sake_log)

        html = Nokogiri::HTML(response.body)
        # 1項目ずつのテキスト（例: "旨味 記録なし"）
        rows = html.css("dl > div").map { |row| row.text.squish }
        expect(html.at_css("h3:contains('味・香りの詳細記録')")).to be_present
        expect(rows.size).to eq TasteProfile::RECORD_ATTRIBUTES.size
        expect(rows.first).to start_with("甘味 0.0") # 0 は「記録なし」ではなく値として表示
        expect(rows).to include("旨味 記録なし")
        expect(html.css("progress").size).to eq 1 # バーは記録した項目（甘味）だけ
        # 炭酸感は4段階の区切りボタンで、記録した「無し」だけが緑（btn-primary）
        expect(rows.last).to start_with("炭酸感 無し")
        expect(html.css("dl .join-item").map { |item| item.text.squish }).to eq TasteProfile::CARBONATION_LABELS.values
        expect(html.css("dl .join-item.btn-primary").map { |item| item.text.squish }).to eq [ "無し" ]
      end

      it "全項目が記録なしなら「味わい」欄自体を表示しない" do
        create(:taste_profile, :blank, sake_log: sake_log)

        get sake_log_path(sake_log)

        expect(response.body).not_to include("味・香りの詳細記録")
        expect(response.body).not_to include("味わい")
      end

      it "味わいの詳細が無い記録でも表示できる" do
        get sake_log_path(sake_log)

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("味わい")
      end
    end
  end

  # 詳細記録セクションの開閉
  describe "味・香りの詳細記録セクション" do
    # 詳細記録セクション（<details>）を取り出す
    def detail_section
      Nokogiri::HTML(response.body).at_css("details.collapse")
    end

    it "新規作成画面では閉じた状態で表示される" do
      get new_sake_log_path

      expect(detail_section).to be_present
      expect(detail_section["open"]).to be_nil
    end

    it "編集画面では、記録済みなら開いた状態で表示される" do
      sake_log = create(:sake_log, user: user)
      create(:taste_profile, :blank, sake_log: sake_log, finish_intensity: 8.0)

      get edit_sake_log_path(sake_log)

      expect(detail_section["open"]).to be_present
    end

    it "編集画面でも、未記録なら閉じた状態で表示される" do
      sake_log = create(:sake_log, user: user)

      get edit_sake_log_path(sake_log)

      expect(detail_section["open"]).to be_nil
    end
  end

  # 作成・更新で味わいの詳細が保存される
  describe "味わいの詳細の保存" do
    let(:brand) { create(:brand) }
    let(:base_params) do
      { product_name: "純米吟醸", brand_id: brand.id, rating: 3, taste_strength: 5.0, aroma_strength: 5.0 }
    end

    it "POST /sake_logs で保存される" do
      post sake_logs_path, params: {
        sake_log: base_params.merge(sweetness_intensity: "6.5", umami_intensity: "", carbonation: "gassy")
      }

      taste_profile = SakeLog.last.taste_profile
      expect(taste_profile.sweetness_intensity).to eq 6.5
      expect(taste_profile.umami_intensity).to be_nil
      expect(taste_profile.carbonation).to eq "gassy"
    end

    it "PATCH /sake_logs/:id でクリアすると nil に戻る" do
      sake_log = create(:sake_log, user: user)
      create(:taste_profile, sake_log: sake_log)

      patch sake_log_path(sake_log), params: { sake_log: { sweetness_intensity: "", carbonation: "" } }

      taste_profile = sake_log.reload.taste_profile
      expect(taste_profile.sweetness_intensity).to be_nil
      expect(taste_profile.carbonation).to be_nil
      expect(taste_profile.umami_intensity).to eq 5.0 # 送っていない項目はそのまま
    end
  end

  describe "DELETE /sake_logs/:id" do
    context "一覧画面（タイムライン・マイログ）からの削除のとき" do
      it "Turbo Stream でそのカードだけ削除する" do
        %w[timeline mylog].each do |origin|
          sake_log = create(:sake_log, user: user)

          delete sake_log_path(sake_log, from: origin)

          expect(response.media_type).to eq "text/vnd.turbo-stream.html"
          expect(SakeLog.exists?(sake_log.id)).to be false
        end
      end
    end

    # 日本酒詳細は「最後の記録かどうか」で応答が変わる
    context "日本酒詳細からの削除のとき" do
      let(:sake) { create(:sake) }

      it "記録が他に残っていれば Turbo Stream でそのカードだけ削除する" do
        sake_log = create(:sake_log, user: user, sake: sake)
        create(:sake_log, sake: sake) # 他のユーザーの記録。これが残るので日本酒は消えない

        delete sake_log_path(sake_log, from: "sake")

        expect(response.media_type).to eq "text/vnd.turbo-stream.html"
        expect(SakeLog.exists?(sake_log.id)).to be false
      end

      it "最後の記録だった場合は、日本酒ごと消えるためマイログ一覧へリダイレクトする" do
        sake_log = create(:sake_log, user: user, sake: sake)

        delete sake_log_path(sake_log, from: "sake")

        expect(response).to redirect_to(sake_logs_path)
        expect(response).to have_http_status(:see_other)
        expect(SakeLog.exists?(sake_log.id)).to be false
      end
    end

    context "記録詳細からの削除のとき（from なし）" do
      it "マイログ一覧へリダイレクトする" do
        sake_log = create(:sake_log, user: user)

        delete sake_log_path(sake_log)

        expect(response).to redirect_to(sake_logs_path)
        expect(response).to have_http_status(:see_other)
        expect(SakeLog.exists?(sake_log.id)).to be false
      end
    end
  end
end
