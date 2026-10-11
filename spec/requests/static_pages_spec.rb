require "rails_helper"

RSpec.describe "静的ページ", type: :request do
  def html
    Nokogiri::HTML(response.body)
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

  describe "ヘッダーのメニュー" do
    it "未ログインでも、お問い合わせへのリンクが表示される" do
      get root_path

      expect(html.at_css(%(header a[href="#{contact_path}"]))).to be_present
    end

    it "ログイン中も、お問い合わせへのリンクが表示される" do
      sign_in create(:user)
      get root_path

      expect(html.at_css(%(header a[href="#{contact_path}"]))).to be_present
    end
  end
end
