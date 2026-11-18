require "rails_helper"

RSpec.describe "静的ページ", type: :request do
  def html
    Nokogiri::HTML(response.body)
  end

  describe "GET /（root）" do
    it "未ログインなら TOPページが表示される" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(html.at_css("main h1").text).to include("ラベルを撮るだけ。")
    end

    it "ログイン済みならタイムラインへリダイレクトされる" do
      sign_in create(:user)
      get root_path

      expect(response).to redirect_to(timeline_path)
    end
  end

  describe "GET /about" do
    it "未ログインなら、新規登録とタイムライン（登録せずに見てみる）へのボタンが表示される" do
      get about_path

      expect(response).to have_http_status(:ok)
      expect(html.at_css(%(main a[href="#{new_user_registration_path}"]))).to be_present
      expect(html.at_css(%(main a[href="#{timeline_path}"]))).to be_present
    end

    it "ログイン中もリダイレクトされず、新規登録の代わりに記録するボタンが表示される" do
      sign_in create(:user)
      get about_path

      expect(response).to have_http_status(:ok)
      expect(html.at_css(%(main a[href="#{new_sake_log_path}"]))).to be_present
      expect(html.at_css(%(main a[href="#{new_user_registration_path}"]))).to be_nil
    end

    it "アプリとしてインストールするボタンがあり、メニューと同じ仕組みで動く" do
      get about_path

      install_section = html.at_css('main section[data-controller="pwa-install"]')
      expect(install_section.at_css(%(a[href="#{install_path}"]))[:"data-action"]).to eq "pwa-install#install"
    end

    it "canonical が /（root）になっている" do
      get about_path

      expect(html.at_css('link[rel="canonical"]')[:href]).to eq root_url
    end

    it "ページのタイトルにサービスの説明が入っている" do
      get about_path

      expect(html.at_css("title").text).to eq "吟ログ | #{I18n.t('static_pages.top.title')}"
    end
  end

  describe "GET /contact" do
    it "未ログインでも 200 が返る" do
      get contact_path

      expect(response).to have_http_status(:ok)
    end

    it "Google フォームへのリンクがあり、別タブで開く" do
      get contact_path

      form_link = html.at_css(%(a[href="#{StaticPagesController::CONTACT_FORM_URL}"]))
      expect(form_link).to be_present
      expect(form_link["target"]).to eq "_blank"
    end
  end

  describe "GET /privacy" do
    it "未ログインでも 200 が返る" do
      get privacy_path

      expect(response).to have_http_status(:ok)
    end

    # 開示・削除の依頼を受け付ける窓口として、お問い合わせページを案内している
    it "本文にお問い合わせページへのリンクがある" do
      get privacy_path

      expect(html.at_css(%(main a[href="#{contact_path}"]))).to be_present
    end
  end

  describe "GET /terms" do
    it "未ログインでも 200 が返る" do
      get terms_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /install" do
    it "未ログインでも 200 が返る" do
      get install_path

      expect(response).to have_http_status(:ok)
    end

    it "Android・iPhone・パソコンの手順の見出しが表示される" do
      get install_path

      headings = html.css("main details h2").map { |heading| heading.text.squish }
      expect(headings).to include(
        a_string_including(I18n.t("static_pages.install.android.heading")),
        a_string_including(I18n.t("static_pages.install.iphone.heading")),
        a_string_including(I18n.t("static_pages.install.pc.heading"))
      )
    end
  end

  describe "ヘッダーのメニュー" do
    it "未ログインでも、お問い合わせへのリンクが表示される" do
      get about_path

      expect(html.at_css(%(header a[href="#{contact_path}"]))).to be_present
    end

    it "ログイン中も、お問い合わせへのリンクが表示される" do
      sign_in create(:user)
      get about_path

      expect(html.at_css(%(header a[href="#{contact_path}"]))).to be_present
    end

    it "未ログインでも、プライバシーポリシーへのリンクが表示される" do
      get about_path

      expect(html.at_css(%(header a[href="#{privacy_path}"]))).to be_present
    end

    it "未ログインでも、利用規約へのリンクが表示される" do
      get about_path

      expect(html.at_css(%(header a[href="#{terms_path}"]))).to be_present
    end
  end
end
