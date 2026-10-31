require 'rails_helper'

RSpec.describe "フッター", type: :request do
  let(:user) { create(:user) }

  it "ホーム・検索・記録・マイログ・好み分析へのリンクがある" do
    get timeline_path

    paths = Nokogiri::HTML(response.body).css("footer a").map { |link| link[:href] }
    expect(paths).to contain_exactly(timeline_path, sakes_path, new_sake_log_path, sake_logs_path, preference_analysis_path)
  end

  it "開いている画面のボタンがアクティブになる" do
    sign_in user

    get preference_analysis_path

    active_link = Nokogiri::HTML(response.body).at_css("footer a.dock-active")
    expect(active_link[:href]).to eq preference_analysis_path
  end
end
