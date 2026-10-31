require "rails_helper"

RSpec.describe "サイトマップ", type: :request do
  describe "GET /sitemap.xml" do
    let(:sake) { create(:sake) }
    let!(:sake_log) { create(:sake_log, sake: sake) }

    # サイトマップに載っている URL の一覧
    def sitemap_urls
      Nokogiri::XML(response.body).remove_namespaces!.css("url loc").map(&:text)
    end

    it "未ログインでも XML が返る" do
      get "/sitemap.xml"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq "application/xml"
    end

    it "公開ページの URL が載っている" do
      get "/sitemap.xml"

      expect(sitemap_urls).to include(root_url, timeline_url, sakes_url, contact_url, privacy_url, terms_url)
    end

    it "日本酒詳細と記録詳細の URL が載っている" do
      get "/sitemap.xml"

      expect(sitemap_urls).to include(sake_url(sake), sake_log_url(sake_log))
    end
  end
end
