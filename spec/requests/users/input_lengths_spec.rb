require "rails_helper"

# 文字数の上限・下限を、送信する前に入力欄で止める
RSpec.describe "アカウント関連画面の入力欄の文字数", type: :request do
  let(:email_max) { User::EMAIL_MAX_LENGTH.to_s }
  let(:password_min) { User.password_length.min.to_s }
  let(:password_max) { User.password_length.max.to_s }

  # 表示中の画面から、name 属性で入力欄を探す
  # @param name [String] 入力欄の name 属性（例: "user[email]"）
  # @return [Nokogiri::XML::Element, nil] 見つかった入力欄
  def input_named(name)
    Nokogiri::HTML(response.body).at_css(%(input[name="#{name}"]))
  end

  it "新規登録: email に maxlength、password と確認用に minlength / maxlength が付いている" do
    get new_user_registration_path

    expect(input_named("user[email]")["maxlength"]).to eq email_max
    %w[user[password] user[password_confirmation]].each do |name|
      expect(input_named(name)["minlength"]).to eq(password_min), "#{name} の minlength が違う"
      expect(input_named(name)["maxlength"]).to eq(password_max), "#{name} の maxlength が違う"
    end
  end

  it "アカウント編集: 新しいパスワードには minlength / maxlength、現在のパスワードには maxlength だけが付いている" do
    sign_in create(:user)
    get edit_user_registration_path

    expect(input_named("user[email]")["maxlength"]).to eq email_max
    %w[user[password] user[password_confirmation]].each do |name|
      expect(input_named(name)["minlength"]).to eq(password_min), "#{name} の minlength が違う"
      expect(input_named(name)["maxlength"]).to eq(password_max), "#{name} の maxlength が違う"
    end
    expect(input_named("user[current_password]")["minlength"]).to be_nil
    expect(input_named("user[current_password]")["maxlength"]).to eq password_max
  end

  it "ログイン: email に maxlength、password には maxlength だけが付いている" do
    get new_user_session_path

    expect(input_named("user[email]")["maxlength"]).to eq email_max
    expect(input_named("user[password]")["minlength"]).to be_nil
    expect(input_named("user[password]")["maxlength"]).to eq password_max
  end

  it "パスワード再設定メールの送信: email に maxlength が付いている" do
    get new_user_password_path

    expect(input_named("user[email]")["maxlength"]).to eq email_max
  end

  # 画面の表示ではトークンの正しさを確かめないため、仮の値で開ける
  it "パスワード再設定: password と確認用に minlength / maxlength が付いている" do
    get edit_user_password_path(reset_password_token: "dummy-token")

    %w[user[password] user[password_confirmation]].each do |name|
      expect(input_named(name)["minlength"]).to eq(password_min), "#{name} の minlength が違う"
      expect(input_named(name)["maxlength"]).to eq(password_max), "#{name} の maxlength が違う"
    end
  end

  it "確認メールの再送信: email に maxlength が付いている" do
    get new_user_confirmation_path

    expect(input_named("user[email]")["maxlength"]).to eq email_max
  end
end
