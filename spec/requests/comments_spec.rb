require "rails_helper"

RSpec.describe "コメント", type: :request do
  let(:owner) { create(:user) }
  let(:user) { create(:user) }
  let(:sake) { create(:sake) }
  let!(:sake_log) { create(:sake_log, user: owner, sake: sake) }

  # Turbo からのフォーム送信と同じ Accept ヘッダー
  let(:turbo_stream_headers) { { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" } }

  def html
    Nokogiri::HTML(response.body)
  end

  def dom_id(record, prefix = nil)
    ActionView::RecordIdentifier.dom_id(record, prefix)
  end

  # ブロック内で発行された、パターンに合う SQL の数を返す
  def count_queries(pattern)
    count = 0
    counter = ->(*, payload) { count += 1 if payload[:sql].match?(pattern) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  describe "POST /sake_logs/:sake_log_id/comments" do
    let(:params) { { comment: { body: "香りが華やか" } } }

    context "未ログインのとき" do
      it "投稿されず、ログイン画面へ移動する" do
        expect { post sake_log_comments_path(sake_log), params: params }.not_to change(Comment, :count)
        expect(response).to redirect_to new_user_session_path
      end
    end

    context "ログイン中のとき" do
      before { sign_in user }

      it "投稿でき、一覧の末尾への追加・フォームのリセット・件数の更新を Turbo Stream で返す" do
        expect { post sake_log_comments_path(sake_log), params: params, headers: turbo_stream_headers }
          .to change { sake_log.comments.where(user: user).count }.from(0).to(1)

        expect(response.media_type).to eq Mime[:turbo_stream]
        expect(response.body).to include %(action="append" target="comments_list")
        expect(response.body).to include "香りが華やか"
        expect(response.body).to include %(action="update" target="comment_form")
        expect(response.body).to include %(action="replace" target="#{dom_id(sake_log, :comment_button)}")
      end

      it "他人の記録にも、自分の記録にもコメントできる" do
        own_sake_log = create(:sake_log, user: user, sake: sake)

        expect { post sake_log_comments_path(own_sake_log), params: params, headers: turbo_stream_headers }
          .to change(Comment, :count).by(1)
      end

      it "本文が空ならエラー付きのフォームを返し、保存しない" do
        expect { post sake_log_comments_path(sake_log), params: { comment: { body: " " } }, headers: turbo_stream_headers }
          .not_to change(Comment, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include %(action="update" target="comment_form")
        expect(response.body).to include "コメントを入力してください"
      end

      it "501文字以上ならエラー付きのフォームを返し、保存しない" do
        expect { post sake_log_comments_path(sake_log), params: { comment: { body: "あ" * 501 } }, headers: turbo_stream_headers }
          .not_to change(Comment, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include "500文字以内"
      end
    end
  end

  describe "GET /sake_logs/:sake_log_id/comments/:id/edit" do
    let!(:comment) { create(:comment, sake_log: sake_log, user: user, body: "編集前") }

    before { sign_in user }

    it "Turbo Frame から開くと、コメント1件分の枠に編集フォームを返す" do
      get edit_comment_path(comment), headers: { "Turbo-Frame" => dom_id(comment) }

      expect(response).to have_http_status(:ok)
      form = html.at_css("turbo-frame##{dom_id(comment)} form")
      expect(form["action"]).to eq comment_path(comment)
      expect(form.at_css("textarea").text.strip).to eq "編集前"
    end

    it "Turbo Frame 以外で開くと記録詳細へ移動する" do
      get edit_comment_path(comment)

      expect(response).to redirect_to sake_log_path(sake_log)
    end

    it "他人のコメントは開けない" do
      other_comment = create(:comment, sake_log: sake_log)

      get edit_comment_path(other_comment), headers: { "Turbo-Frame" => dom_id(other_comment) }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /sake_logs/:sake_log_id/comments/:id" do
    let!(:comment) { create(:comment, sake_log: sake_log, user: user, body: "編集前") }

    before { sign_in user }

    it "自分のコメントを更新し、コメント1件分を Turbo Stream で差し替える" do
      patch comment_path(comment), params: { comment: { body: "編集後" } }, headers: turbo_stream_headers

      expect(comment.reload.body).to eq "編集後"
      expect(response.media_type).to eq Mime[:turbo_stream]
      expect(response.body).to include %(action="replace" target="#{dom_id(comment)}")
    end

    it "更新後のコメントには「編集済み」が付く" do
      travel_to(1.minute.from_now) do
        patch comment_path(comment), params: { comment: { body: "編集後" } }, headers: turbo_stream_headers
      end

      expect(response.body).to include "編集済み"
    end

    it "本文が空なら更新せず、エラー付きの編集フォームを返す" do
      patch comment_path(comment), params: { comment: { body: "" } }, headers: turbo_stream_headers

      expect(comment.reload.body).to eq "編集前"
      expect(response).to have_http_status(:unprocessable_entity)
      expect(html.at_css("turbo-frame##{dom_id(comment)} #error_explanation")).to be_present
    end

    it "他人のコメントは更新できない" do
      other_comment = create(:comment, sake_log: sake_log, body: "他人のコメント")

      patch comment_path(other_comment), params: { comment: { body: "書き換え" } }, headers: turbo_stream_headers

      expect(response).to have_http_status(:not_found)
      expect(other_comment.reload.body).to eq "他人のコメント"
    end
  end

  describe "DELETE /sake_logs/:sake_log_id/comments/:id" do
    let!(:comment) { create(:comment, sake_log: sake_log, user: user) }

    context "未ログインのとき" do
      it "削除されず、ログイン画面へ移動する" do
        expect { delete comment_path(comment) }.not_to change(Comment, :count)
        expect(response).to redirect_to new_user_session_path
      end
    end

    context "ログイン中のとき" do
      before { sign_in user }

      it "自分のコメントを削除し、一覧から消す・件数を更新する Turbo Stream を返す" do
        expect { delete comment_path(comment), headers: turbo_stream_headers }
          .to change(Comment, :count).by(-1)

        expect(response.media_type).to eq Mime[:turbo_stream]
        expect(response.body).to include %(action="remove" target="#{dom_id(comment)}")
        expect(response.body).to include %(action="replace" target="#{dom_id(sake_log, :comment_button)}")
      end

      it "記録の持ち主でも、他人のコメントは削除できない" do
        sign_in owner

        expect { delete comment_path(comment), headers: turbo_stream_headers }
          .not_to change(Comment, :count)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "記録詳細のコメント欄" do
    it "コメントが古い順に並ぶ" do
      create(:comment, sake_log: sake_log, body: "後のコメント", created_at: 1.day.ago)
      create(:comment, sake_log: sake_log, body: "先のコメント", created_at: 2.days.ago)

      get sake_log_path(sake_log)

      bodies = html.css("#comments_list turbo-frame p.break-words").map { |node| node.text.strip }
      expect(bodies).to eq %w[先のコメント 後のコメント]
    end

    it "別の記録のコメントは表示されない" do
      create(:comment, body: "別の記録のコメント")

      get sake_log_path(sake_log)

      expect(response.body).not_to include "別の記録のコメント"
    end

    it "コメント0件のときも「まだコメントはありません」を一覧の中に置いている" do
      get sake_log_path(sake_log)

      expect(html.at_css("#comments_list").text).to include "まだコメントはありません"
    end

    it "未ログインのときはフォームの代わりにログイン画面へのリンクを出す" do
      get sake_log_path(sake_log)

      expect(html.at_css("#comment_form")).to be_nil
      expect(html.at_css(%(#comments a[href="#{new_user_session_path}"]))).to be_present
    end

    it "ログイン中は一覧の下に投稿フォームを出す" do
      sign_in user

      get sake_log_path(sake_log)

      form = html.at_css("#comment_form form")
      expect(form["action"]).to eq sake_log_comments_path(sake_log)
      expect(form.at_css("textarea")["maxlength"]).to eq Comment::BODY_MAX_LENGTH.to_s
    end

    it "編集したコメントにだけ「編集済み」を出す" do
      edited_comment = create(:comment, sake_log: sake_log, created_at: 1.day.ago, updated_at: 1.hour.ago)
      plain_comment = create(:comment, sake_log: sake_log)

      get sake_log_path(sake_log)

      expect(html.at_css("##{dom_id(edited_comment)}").text).to include "編集済み"
      expect(html.at_css("##{dom_id(plain_comment)}").text).not_to include "編集済み"
    end

    it "編集・削除ボタンは自分のコメントにだけ出る" do
      own_comment = create(:comment, sake_log: sake_log, user: user)
      other_comment = create(:comment, sake_log: sake_log)
      sign_in user

      get sake_log_path(sake_log)

      expect(html.at_css("#button-edit-comment-#{own_comment.id}")).to be_present
      expect(html.at_css("#button-delete-comment-#{own_comment.id}")).to be_present
      expect(html.at_css("#button-edit-comment-#{other_comment.id}")).to be_nil
      expect(html.at_css("#button-delete-comment-#{other_comment.id}")).to be_nil
    end

    it "コメントアイコンは同じページのコメント欄へのリンクで、件数を表示する" do
      create_list(:comment, 2, sake_log: sake_log)

      get sake_log_path(sake_log)

      button = html.at_css("##{dom_id(sake_log, :comment_button)}")
      expect(button["href"]).to eq "#comments"
      expect(button.text.strip).to end_with "2"
    end

    it "ユーザーの N+1 が発生しない" do
      create_list(:comment, 3, sake_log: sake_log)

      # 記録の投稿者 1回 + コメントした人 1回
      expect(count_queries(/FROM "users"/) { get sake_log_path(sake_log) }).to eq 2
    end
  end

  # タイムライン・日本酒詳細は同じカードを使うので、同じ確認をする
  shared_examples "コメント欄へ移動するコメントアイコン" do |origin|
    it "件数を表示し、記録詳細のコメント欄へのリンクになっている" do
      create_list(:comment, 2, sake_log: sake_log)

      get path

      button = html.at_css("##{dom_id(sake_log, :comment_button)}")
      expect(button["href"]).to eq sake_log_path(sake_log, from: origin, anchor: "comments")
      expect(button["class"]).to include "z-20"
      expect(button.text.strip).to end_with "2"
    end

    it "カードが増えても comments の SELECT は1回だけ" do
      create_list(:sake_log, 3, sake: sake).each { |log| create(:comment, sake_log: log) }

      expect(count_queries(/FROM "comments"/) { get path }).to eq 1
    end
  end

  describe "タイムライン" do
    let(:path) { timeline_path }

    it_behaves_like "コメント欄へ移動するコメントアイコン", "timeline"
  end

  describe "日本酒詳細のみんなの記録" do
    let(:path) { sake_path(sake) }

    it_behaves_like "コメント欄へ移動するコメントアイコン", "sake"
  end

  describe "マイログ一覧" do
    let!(:own_sake_log) { create(:sake_log, user: user, sake: sake) }
    let(:comments_link_path) { sake_log_path(own_sake_log, from: "mylog", anchor: "comments") }

    before { sign_in user }

    it "コメント数が、記録詳細のコメント欄へのリンクになる" do
      create(:comment, sake_log: own_sake_log)

      get sake_logs_path

      link = html.at_css(%(a[href="#{comments_link_path}"]))
      expect(link.text).to include "1"
    end

    it "コメント0件でも、コメント欄へのリンクになる（投稿フォームへ移動できる）" do
      get sake_logs_path

      link = html.at_css(%(a[href="#{comments_link_path}"]))
      expect(link.text).to include "0"
    end

    it "カードが増えても comments の SELECT は1回だけ" do
      create_list(:sake_log, 3, user: user).each { |log| create(:comment, sake_log: log) }

      expect(count_queries(/FROM "comments"/) { get sake_logs_path }).to eq 1
    end
  end
end
