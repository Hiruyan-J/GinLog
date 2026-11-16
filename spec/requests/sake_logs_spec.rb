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

    # スライダーに name が付くと、触っていない項目まで表示用の初期値（5.0）で保存されてしまうため
    it "味わいのスライダーは送信されず、送信用の hidden field は空（記録なし）になる" do
      get new_sake_log_path

      html = Nokogiri::HTML(response.body)
      TasteProfile::INTENSITY_SCALES.each_key do |attribute|
        expect(html.at_css("input[type=range]#sake_log_#{attribute}")["name"]).to be_nil
        expect(html.at_css("input[type=hidden][name='sake_log[#{attribute}]']")["value"]).to be_blank
      end
      expect(html.at_css("input[type=hidden][name='sake_log[carbonation]']")["value"]).to be_blank
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

  # 必須項目は送信前にブラウザで止める（エラーで写真が消えるのを防ぐ）
  describe "必須項目の required" do
    # required を付ける入力欄の CSS セレクタ
    let(:required_selectors) do
      [
        "input[name='sake_log[manual_brand_name]']",
        "input[name='sake_log[manual_brewery_name]']",
        "select[name='sake_log[area_id]']",
        "input[name='sake_log[product_name]']",
        "input[type=radio][name='sake_log[rating]']"
      ]
    end

    # すべての必須項目に required が付いているか確認する
    # @return [void]
    def expect_required_fields
      html = Nokogiri::HTML(response.body)
      required_selectors.each do |selector|
        fields = html.css(selector)
        expect(fields).to be_present, "#{selector} が見つからない"
        expect(fields).to all(satisfy { |field| field.key?("required") })
      end
    end

    it "新規作成画面の必須項目に required が付いている" do
      get new_sake_log_path

      expect_required_fields
    end

    it "編集画面の必須項目に required が付いている" do
      sake_log = create(:sake_log, user: user)

      get edit_sake_log_path(sake_log)

      expect_required_fields
    end

    # 香りの濃淡・味の濃淡は、触るまで「未入力」として扱う
    context "香りの濃淡・味の濃淡" do
      let(:strength_attributes) { %i[aroma_strength taste_strength] }

      it "新規作成画面では、スライダーは送信されず、送信用の hidden field は空（未入力）になる" do
        get new_sake_log_path

        html = Nokogiri::HTML(response.body)
        strength_attributes.each do |attribute|
          expect(html.at_css("input[type=range]#sake_log_#{attribute}")["name"]).to be_nil
          expect(html.at_css("input[type=hidden][name='sake_log[#{attribute}]']")["value"]).to be_blank
        end
      end

      it "必須として扱われ、クリアボタンは出ない" do
        get new_sake_log_path

        html = Nokogiri::HTML(response.body)
        strength_attributes.each do |attribute|
          field = html.at_css("input[type=range]#sake_log_#{attribute}")
                      .ancestors("[data-controller='clearable-field']").first
          expect(field["data-clearable-field-required-value"]).to eq "true"
          expect(field.at_css("button[data-action='clearable-field#clear']")).to be_nil
        end
      end

      it "編集画面では、記録済みの値が hidden field に入る" do
        sake_log = create(:sake_log, user: user, aroma_strength: 7.5, taste_strength: 2.0)

        get edit_sake_log_path(sake_log)

        html = Nokogiri::HTML(response.body)
        expect(html.at_css("input[type=hidden][name='sake_log[aroma_strength]']")["value"]).to eq "7.5"
        expect(html.at_css("input[type=hidden][name='sake_log[taste_strength]']")["value"]).to eq "2.0"
      end

      it "未入力（空文字）のまま送信されたら、登録されずにエラーになる" do
        brand = create(:brand)
        params = { product_name: "純米吟醸", brand_id: brand.id, rating: 3, aroma_strength: "", taste_strength: "" }

        expect {
          post sake_logs_path, params: { sake_log: params }
        }.not_to change(SakeLog, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # 文字数の上限を超えて入力できないようにする
  describe "入力欄の maxlength" do
    it "銘柄名・蔵元名・商品名・感想に、モデルと同じ上限の maxlength が付いている" do
      max_lengths = {
        "input[name='sake_log[manual_brand_name]']" => Brand::NAME_MAX_LENGTH,
        "input[name='sake_log[manual_brewery_name]']" => Brewery::NAME_MAX_LENGTH,
        "input[name='sake_log[product_name]']" => Sake::PRODUCT_NAME_MAX_LENGTH,
        "textarea[name='sake_log[review]']" => SakeLog::REVIEW_MAX_LENGTH
      }

      get new_sake_log_path

      html = Nokogiri::HTML(response.body)
      max_lengths.each do |selector, max_length|
        expect(html.at_css(selector)["maxlength"]).to eq(max_length.to_s), "#{selector} の maxlength が違う"
      end
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
