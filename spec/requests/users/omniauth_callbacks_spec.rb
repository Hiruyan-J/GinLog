require "rails_helper"

RSpec.describe "Google ログイン", type: :request do
  # Google から届く認証情報を用意する
  def mock_google_auth(email:, uid: "12345", name: "山田太郎")
    OmniAuth.config.mock_auth[:google_oauth2] =
      OmniAuth::AuthHash.new(provider: "google_oauth2", uid: uid, info: { email: email, name: name })
  end

  # 「Google でログイン」ボタンを押し、Google から戻ってくるところまでを行う
  def login_with_google
    post user_google_oauth2_omniauth_authorize_path
    follow_redirect!
  end

  # 用意した認証情報が、他のテストに残らないようにする
  after { OmniAuth.config.mock_auth[:google_oauth2] = nil }

  describe "ボタンの表示" do
    it "ログイン画面に表示される" do
      get new_user_session_path

      expect(response.body).to include "Googleでログイン"
    end

    it "新規登録画面に表示される" do
      get new_user_registration_path

      expect(response.body).to include "Googleでログイン"
    end

    it "パスワード再設定画面には表示されない" do
      get new_user_password_path

      expect(response.body).not_to include "Googleでログイン"
    end
  end

  describe "未登録の Google アカウントでログイン" do
    before { mock_google_auth(email: "new@example.com") }

    it "ユーザーが作られ、ログイン状態でトップへ移動する" do
      expect { login_with_google }.to change(User, :count).by(1)
      expect(response).to redirect_to root_path
    end

    it "ユーザー名を変更できる旨の案内が表示される" do
      login_with_google
      follow_redirect!

      expect(response.body).to include "マイアカウントから変更できます"
    end
  end

  describe "登録済みの Google アカウントでログイン" do
    before do
      create(:user, :google, uid: "12345", email: "taro@example.com")
      mock_google_auth(email: "taro@example.com", uid: "12345")
    end

    it "ユーザーは増えず、ログイン状態でトップへ移動する" do
      expect { login_with_google }.not_to change(User, :count)
      expect(response).to redirect_to root_path
    end

    it "ユーザー名の案内は表示されない" do
      login_with_google
      follow_redirect!

      expect(response.body).not_to include "マイアカウントから変更できます"
    end
  end

  describe "同じメールアドレスでメール登録済みのユーザーが Google でログイン" do
    let!(:user) { create(:user, email: "taro@example.com") }

    before { mock_google_auth(email: "taro@example.com") }

    # マイアカウントは本人専用の画面。既存ユーザーのメールアドレスが出ればひも付いている
    it "新しいユーザーは作られず、既存のユーザーとしてログインする" do
      expect { login_with_google }.not_to change(User, :count)

      get mypage_path
      expect(response.body).to include user.email
    end

    it "ひも付け後も、メールアドレスとパスワードでログインできる" do
      login_with_google
      delete destroy_user_session_path

      post user_session_path, params: { user: { email: "taro@example.com", password: "password" } }
      expect(response).to redirect_to root_path
    end
  end

  describe "Google 側で認証に失敗・キャンセルした場合" do
    before { OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials }

    it "ログイン画面へ戻り、エラーメッセージが表示される" do
      login_with_google
      expect(response).to redirect_to new_user_session_path

      follow_redirect!
      expect(response.body).to include "ログインに失敗しました"
    end
  end
end
