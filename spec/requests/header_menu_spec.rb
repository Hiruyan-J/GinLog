require 'rails_helper'

RSpec.describe "ヘッダーのメニュー", type: :request do
  let(:user) { create(:user) }

  # ハンバーガーメニューにあるリンク先を返す（フッターや左上のボタンは含めない）
  # @return [Array<String>] リンク先のパス
  def menu_paths
    Nokogiri::HTML(response.body).css("header .menu a").map { |link| link[:href] }
  end

  context "ログインしていないとき" do
    before { get timeline_path }

    it "ホーム・日本酒検索・マイログ・好み分析へのリンクがある" do
      expect(menu_paths).to include(root_path, sakes_path, sake_logs_path, preference_analysis_path)
    end

    it "ログインと新規登録へのリンクがあり、マイアカウントへのリンクはない" do
      expect(menu_paths).to include(new_user_session_path, new_user_registration_path)
      expect(menu_paths).not_to include(mypage_path)
    end
  end

  context "ログインしているとき" do
    before do
      sign_in user
      get timeline_path
    end

    it "ホーム・日本酒検索・マイログ・好み分析へのリンクがある" do
      expect(menu_paths).to include(root_path, sakes_path, sake_logs_path, preference_analysis_path)
    end

    it "マイアカウントへのリンクがあり、ログインと新規登録へのリンクはない" do
      expect(menu_paths).to include(mypage_path)
      expect(menu_paths).not_to include(new_user_session_path, new_user_registration_path)
    end
  end
end
