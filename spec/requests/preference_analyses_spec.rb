require 'rails_helper'

RSpec.describe "PreferenceAnalyses", type: :request do
  let(:user) { create(:user) }

  describe "GET /preference_analysis" do
    context "ログインしていないとき" do
      it "ログイン画面へリダイレクトする" do
        get preference_analysis_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "記録が1件もないとき" do
      before { sign_in user }

      it "記録がないことと「日本酒を記録する」ボタンを表示する" do
        get preference_analysis_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include "まだ記録がありません"
        expect(response.body).to include new_sake_log_path
        expect(response.body).not_to include "フレーバー別分析"
      end
    end

    context "記録があるとき" do
      let(:niigata) { create(:area, name: "新潟県") }
      let(:iwate) { create(:area, name: "岩手県") }

      before do
        sign_in user
        create(:sake_log, user: user, rating: 5, taste_strength: 3.0, aroma_strength: 2.0, sake: sake_in(niigata)) # 左下
        create(:sake_log, user: user, rating: 2, taste_strength: 8.0, aroma_strength: 8.0, sake: sake_in(iwate)) # 右上
      end

      # @param area [Area] 蔵元がある都道府県
      # @return [Sake]
      def sake_in(area)
        create(:sake, brand: create(:brand, brewery: create(:brewery, area: area)))
      end

      it "一番好きな象限と、その象限で絞り込んだ検索へのリンクを表示する" do
        get preference_analysis_path

        expect(response.body).to include "味がスッキリ・香りが穏やか"
        expect(response.body).to include ERB::Util.html_escape(sakes_path(quadrants: [ "aroma_low_taste_light" ]))
      end

      it "記録のない象限は「未記録」と表示する" do
        get preference_analysis_path

        expect(response.body).to include "未記録"
      end

      it "都道府県のタイルに平均と件数を表示し、凡例で読み方を説明する" do
        get preference_analysis_path

        expect(response.body).to include "★5.0"
        expect(response.body).to include "(1)"
        expect(response.body).to include "★好み度の平均 (記録の件数)"
      end

      it "一番好きな都道府県と、その都道府県で絞り込んだ検索へのリンクを表示する" do
        get preference_analysis_path

        expect(response.body).to include "新潟県のお酒を探す"
        expect(response.body).to include sakes_path(area_id: niigata.id)
      end
    end
  end
end
