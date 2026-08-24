require 'rails_helper'

RSpec.describe "SakeLogs", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

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
