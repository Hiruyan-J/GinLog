require "rails_helper"

RSpec.describe "いいね", type: :request do
  let(:owner) { create(:user) }
  let(:user) { create(:user) }
  let(:sake) { create(:sake) }
  let!(:sake_log) { create(:sake_log, user: owner, sake: sake) }

  def html
    Nokogiri::HTML(response.body)
  end

  # ハート（ログイン中は button_to のフォーム）
  def heart_form
    html.at_css("##{ActionView::RecordIdentifier.dom_id(sake_log, :like_button)} form")
  end

  def count_link
    html.at_css(%(a[href="#{sake_log_likes_path(sake_log)}"]))
  end

  # ブロック内で発行された、パターンに合う SQL の数を返す
  def count_queries(pattern)
    count = 0
    counter = ->(*, payload) { count += 1 if payload[:sql].match?(pattern) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  describe "POST /sake_logs/:sake_log_id/like" do
    context "未ログインのとき" do
      it "いいねされず、ログイン画面へ移動する" do
        expect { post sake_log_like_path(sake_log) }.not_to change(Like, :count)
        expect(response).to redirect_to new_user_session_path
      end
    end

    context "ログイン中のとき" do
      before { sign_in user }

      it "いいねが増え、ボタンだけを Turbo Stream で差し替える" do
        expect { post sake_log_like_path(sake_log) }.to change { sake_log.likes.where(user: user).count }.from(0).to(1)

        expect(response.media_type).to eq Mime[:turbo_stream]
        expect(response.body).to include %(target="#{ActionView::RecordIdentifier.dom_id(sake_log, :like_button)}")
        expect(response.body).to include "ms-fill"
      end

      it "いいね済みの記録にもう一度送っても増えない" do
        create(:like, user: user, sake_log: sake_log)

        expect { post sake_log_like_path(sake_log) }.not_to change(Like, :count)
        expect(response).to have_http_status(:ok)
      end

      it "自分の記録にもいいねできる" do
        own_sake_log = create(:sake_log, user: user, sake: sake)

        expect { post sake_log_like_path(own_sake_log) }.to change(Like, :count).by(1)
      end
    end
  end

  describe "DELETE /sake_logs/:sake_log_id/like" do
    let!(:other_like) { create(:like, sake_log: sake_log) }

    context "未ログインのとき" do
      it "いいねは消えず、ログイン画面へ移動する" do
        expect { delete sake_log_like_path(sake_log) }.not_to change(Like, :count)
        expect(response).to redirect_to new_user_session_path
      end
    end

    context "ログイン中のとき" do
      before { sign_in user }

      it "自分のいいねだけが消える" do
        create(:like, user: user, sake_log: sake_log)

        expect { delete sake_log_like_path(sake_log) }.to change(Like, :count).by(-1)
        expect(Like.exists?(other_like.id)).to be true
        expect(response.media_type).to eq Mime[:turbo_stream]
      end

      it "自分のいいねが無ければ、他人のいいねは消えない" do
        expect { delete sake_log_like_path(sake_log) }.not_to change(Like, :count)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /sake_logs/:sake_log_id/likes" do
    let(:frame_headers) { { "Turbo-Frame" => "likes_modal_frame" } }

    it "未ログインでも、いいねした人が新しい順に表示される" do
      create(:like, sake_log: sake_log, user: create(:user, name: "先にいいねした人"), created_at: 2.days.ago)
      create(:like, sake_log: sake_log, user: create(:user, name: "後にいいねした人"), created_at: 1.day.ago)

      get sake_log_likes_path(sake_log), headers: frame_headers

      expect(response).to have_http_status(:ok)
      expect(html.css("#likes_modal_frame li").map { |item| item.text.strip }.map { |text| text[/\S+\z/] })
        .to eq %w[後にいいねした人 先にいいねした人]
    end

    it "別の記録のいいねは表示されない" do
      create(:like, user: create(:user, name: "別の記録の人"))

      get sake_log_likes_path(sake_log), headers: frame_headers

      expect(response.body).not_to include "別の記録の人"
    end

    it "Turbo Frame 以外で開くと記録詳細へ移動する" do
      get sake_log_likes_path(sake_log)

      expect(response).to redirect_to sake_log_path(sake_log)
    end

    it "ユーザーの N+1 が発生しない" do
      create_list(:like, 3, sake_log: sake_log)

      query_count = count_queries(/FROM "users"/) { get sake_log_likes_path(sake_log), headers: frame_headers }

      expect(query_count).to eq 1
    end
  end

  # タイムライン・日本酒詳細は同じカードを使うので、同じ確認をする
  shared_examples "付け外しできるいいねボタン" do
    context "未ログインのとき" do
      before { get path }

      it "ハートはログイン画面へのリンクになる" do
        button = html.at_css("##{ActionView::RecordIdentifier.dom_id(sake_log, :like_button)}")

        expect(button.at_css(%(a[href="#{new_user_session_path}"]))).to be_present
        expect(button.at_css("form")).to be_nil
      end
    end

    context "ログイン中のとき" do
      before { sign_in user }

      it "いいね前は塗りなしのハートで、押すと POST する" do
        get path

        expect(heart_form["action"]).to eq sake_log_like_path(sake_log)
        expect(heart_form.at_css('input[name="_method"]')).to be_nil
        expect(heart_form.at_css(".ms-fill")).to be_nil
      end

      it "いいね済みは塗りつぶしのハートで、押すと DELETE する" do
        create(:like, user: user, sake_log: sake_log)

        get path

        expect(heart_form.at_css('input[name="_method"]')["value"]).to eq "delete"
        expect(heart_form.at_css(".ms-fill")).to be_present
      end

      it "他人だけがいいねした記録のハートは塗りつぶさない" do
        create(:like, sake_log: sake_log)

        get path

        expect(heart_form.at_css(".ms-fill")).to be_nil
      end
    end

    it "いいね0件のとき、いいね数は押せない" do
      get path

      expect(count_link).to be_nil
    end

    it "いいね数を押すと、モーダルの frame に一覧を読み込む" do
      create_list(:like, 2, sake_log: sake_log)

      get path

      expect(count_link["data-turbo-frame"]).to eq "likes_modal_frame"
      expect(count_link.text.strip).to eq "2"
    end

    it "レイアウトに一覧モーダルがある" do
      get path

      expect(html.at_css('dialog[data-controller="likes-modal"] turbo-frame#likes_modal_frame')).to be_present
    end
  end

  describe "タイムライン" do
    let(:path) { timeline_path }

    it_behaves_like "付け外しできるいいねボタン"

    it "いいねボタンはカードのリンクより手前に出ている" do
      get path

      expect(html.at_css("##{ActionView::RecordIdentifier.dom_id(sake_log, :like_button)}")["class"]).to include "z-20"
    end

    it "無限スクロールの2ページ目のカードにも、いいねボタンが出る" do
      create_list(:sake_log, 10, created_at: 1.day.from_now)
      sign_in user

      get timeline_path(page: 2), headers: { "Turbo-Frame" => "timeline_page_2" }

      expect(heart_form["action"]).to eq sake_log_like_path(sake_log)
    end

    it "カードが増えても likes の SELECT は1回だけ" do
      create_list(:sake_log, 3).each { |log| create(:like, sake_log: log) }
      sign_in user

      expect(count_queries(/FROM "likes"/) { get path }).to eq 1
    end
  end

  describe "日本酒詳細のみんなの記録" do
    let(:path) { sake_path(sake) }

    it_behaves_like "付け外しできるいいねボタン"

    it "カードが増えても likes の SELECT は1回だけ" do
      create_list(:sake_log, 3, sake: sake).each { |log| create(:like, sake_log: log) }
      sign_in user

      expect(count_queries(/FROM "likes"/) { get path }).to eq 1
    end
  end

  describe "日本酒記録詳細" do
    let(:path) { sake_log_path(sake_log) }

    it_behaves_like "付け外しできるいいねボタン"
  end

  describe "マイログ一覧" do
    let!(:own_sake_log) { create(:sake_log, user: user, sake: sake) }

    before { sign_in user }

    it "付け外しのボタンは無く、いいね数だけが出る" do
      create(:like, sake_log: own_sake_log, user: user)

      get sake_logs_path

      expect(html.css(%(form[action="#{sake_log_like_path(own_sake_log)}"]))).to be_empty
      link = html.at_css(%(a[href="#{sake_log_likes_path(own_sake_log)}"]))
      expect(link["data-turbo-frame"]).to eq "likes_modal_frame"
      expect(link.text).to include "1"
    end

    it "いいね0件のとき、いいね数は押せない" do
      get sake_logs_path

      expect(html.at_css(%(a[href="#{sake_log_likes_path(own_sake_log)}"]))).to be_nil
    end

    it "自分がいいね済みならハートを塗りつぶし、まだなら塗りつぶさない" do
      liked_log = create(:sake_log, user: user, sake: sake)
      create(:like, sake_log: liked_log, user: user)
      create(:like, sake_log: own_sake_log)

      get sake_logs_path

      expect(html.at_css("##{ActionView::RecordIdentifier.dom_id(liked_log)} .ms-fill")).to be_present
      expect(html.at_css("##{ActionView::RecordIdentifier.dom_id(own_sake_log)} .ms-fill")).to be_nil
    end

    it "カードが増えても likes の SELECT は1回だけ" do
      create_list(:sake_log, 3, user: user).each { |log| create(:like, sake_log: log) }

      expect(count_queries(/FROM "likes"/) { get sake_logs_path }).to eq 1
    end
  end
end
