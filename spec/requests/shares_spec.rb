require "rails_helper"

RSpec.describe "シェア", type: :request do
  let(:owner) { create(:user, name: "ぎんたろう") }
  let(:brand) { create(:brand, name: "而今") }
  let(:sake) { create(:sake, brand: brand, product_name: "純米吟醸") }
  let!(:sake_log) { create(:sake_log, user: owner, sake: sake) }

  def html
    Nokogiri::HTML(response.body)
  end

  # ページ内のシェアボタン（share コントローラの要素）が持つ値を { url: ..., text: ... } の配列で返す
  def share_buttons
    html.css('[data-controller="share"]').map do |button|
      { url: button["data-share-url-value"], text: button["data-share-text-value"] }
    end
  end

  # シェアメニューの「Xでシェア」リンクのクエリを { text: ..., url: ..., hashtags: ... } の配列で返す
  def x_share_queries
    html.css('a[href^="https://x.com/intent/post"]').map do |link|
      Rack::Utils.parse_query(URI.parse(link["href"]).query).symbolize_keys
    end
  end

  # <meta property="og:xxx" content="..."> の content を返す
  def meta_content(property)
    html.at_css("meta[property='#{property}'], meta[name='#{property}']")&.[]("content")
  end

  # シェアメニュー（共通パーシャル shared/_share_button）の、どの画面でも同じになる部分のテスト
  shared_examples "シェアメニュー" do
    before { get path }

    # OS の共有メニューが使えるかはブラウザで決まるため、HTML では隠しておき、JS が表示する
    it "「その他のアプリで共有」があり、最初は隠れている" do
      native_share_item = html.at_css('[data-share-target="nativeShareItem"]')

      expect(native_share_item).to be_present
      expect(native_share_item["hidden"]).not_to be_nil
      expect(native_share_item.text).to include "その他のアプリで共有"
    end

    # 画面側で hashtags: を渡し忘れると #吟ログ #日本酒 だけになるため、画面ごとに確かめる
    it "Xでシェアのハッシュタグに、銘柄名・蔵元名が入る" do
      expect(x_share_queries).to be_present
      expect(x_share_queries.map { |query| query[:hashtags] }).to all(eq "吟ログ,日本酒,#{sake.brand.name},#{sake.brand.brewery.name}")
    end
  end

  describe "タイムライン" do
    it_behaves_like "シェアメニュー" do
      let(:path) { timeline_path }
    end

    it "各カードに記録詳細をシェアするボタンが出る" do
      sign_in create(:user)
      get timeline_path

      expect(share_buttons.map { |button| button[:url] }).to include sake_log_url(sake_log)
      expect(x_share_queries.map { |query| query[:url] }).to include sake_log_url(sake_log)
    end

    it "未ログインでも、各カードに記録詳細をシェアするボタンが出る" do
      get timeline_path

      expect(share_buttons.map { |button| button[:url] }).to include sake_log_url(sake_log)
      expect(x_share_queries.map { |query| query[:url] }).to include sake_log_url(sake_log)
    end

    it "サイト共通の og:image は静的OGP画像になる" do
      get timeline_path

      expect(meta_content("og:image")).to include "ginlog_ogp"
    end
  end

  describe "記録詳細" do
    it_behaves_like "シェアメニュー" do
      let(:path) { sake_log_path(sake_log) }
    end

    it "投稿主が見ると、一人称の投稿文になる" do
      sign_in owner
      get sake_log_path(sake_log)

      expect(share_buttons.first[:url]).to eq sake_log_url(sake_log)
      expect(share_buttons.first[:text]).to include "飲みました"
      expect(x_share_queries.first[:url]).to eq sake_log_url(sake_log)
      expect(x_share_queries.first[:text]).to include "飲みました"
    end

    it "投稿主以外が見ると、投稿者名を入れた紹介の投稿文になる" do
      sign_in create(:user)
      get sake_log_path(sake_log)

      expect(share_buttons.first[:url]).to eq sake_log_url(sake_log)
      expect(share_buttons.first[:text]).to include "ぎんたろうさんの日本酒の記録"
      expect(x_share_queries.first[:url]).to eq sake_log_url(sake_log)
      expect(x_share_queries.first[:text]).to include "ぎんたろうさんの日本酒の記録"
    end

    it "未ログインでも、投稿主以外と同じ投稿文でシェアできる" do
      get sake_log_path(sake_log)

      expect(share_buttons.first[:url]).to eq sake_log_url(sake_log)
      expect(share_buttons.first[:text]).to include "ぎんたろうさんの日本酒の記録"
      expect(x_share_queries.first[:url]).to eq sake_log_url(sake_log)
      expect(x_share_queries.first[:text]).to include "ぎんたろうさんの日本酒の記録"
    end

    it "OGP に記録ごとのタイトルと画像が出力される" do
      get sake_log_path(sake_log)

      expect(meta_content("og:title")).to include "而今 純米吟醸"
      # テスト環境は Cloudinary を使わないため静的OGP画像になる
      expect(meta_content("og:image")).to start_with "http"
      expect(meta_content("twitter:card")).to eq "summary_large_image"
    end
  end

  describe "日本酒詳細" do
    it_behaves_like "シェアメニュー" do
      let(:path) { sake_path(sake) }
    end

    it "未ログインでも、日本酒詳細をシェアするボタンが出る" do
      get sake_path(sake)

      # 見出しのシェアボタンが最初に来る
      expect(share_buttons.first[:url]).to eq sake_url(sake)
      expect(share_buttons.first[:text]).to include "みんなの記録"
      expect(x_share_queries.first[:url]).to eq sake_url(sake)
      expect(x_share_queries.first[:text]).to include "みんなの記録"
    end

    it "og:image は静的OGP画像、説明文は日本酒ごとの内容になる" do
      get sake_path(sake)

      expect(meta_content("og:image")).to include "ginlog_ogp"
      expect(meta_content("og:description")).to include("而今", "純米吟醸")
    end
  end
end
