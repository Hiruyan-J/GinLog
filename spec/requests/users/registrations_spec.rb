require "rails_helper"

RSpec.describe "アカウント編集", type: :request do
  describe "Google 登録ユーザー" do
    let(:user) { create(:user, :google, name: "変更前", email: "taro@example.com") }

    before { sign_in user }

    it "編集画面にパスワード欄が表示されない" do
      get edit_user_registration_path

      expect(response.body).not_to include 'name="user[password]"'
      expect(response.body).not_to include 'name="user[current_password]"'
    end

    it "現在のパスワードなしでユーザー名を変更できる" do
      put user_registration_path, params: { user: { name: "変更後" } }

      expect(user.reload.name).to eq "変更後"
    end

    it "メールアドレスを送っても変更されない" do
      put user_registration_path, params: { user: { name: "変更後", email: "other@example.com" } }

      expect(user.reload.email).to eq "taro@example.com"
      expect(user.unconfirmed_email).to be_nil
    end
  end

  describe "メール登録だけのユーザー" do
    let(:user) { create(:user, name: "変更前") }

    before { sign_in user }

    it "編集画面にパスワード欄が表示される" do
      get edit_user_registration_path

      expect(response.body).to include 'name="user[password]"'
      expect(response.body).to include 'name="user[current_password]"'
    end

    it "現在のパスワードがないとユーザー名を変更できない" do
      put user_registration_path, params: { user: { name: "変更後" } }

      expect(user.reload.name).to eq "変更前"
    end

    it "現在のパスワードがあればユーザー名を変更できる" do
      put user_registration_path, params: { user: { name: "変更後", current_password: "password" } }

      expect(user.reload.name).to eq "変更後"
    end
  end
end
