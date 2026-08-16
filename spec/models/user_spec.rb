require 'rails_helper'

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  name                   :string           not null
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  unconfirmed_email      :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
RSpec.describe User, type: :model do
  describe "バリデーション" do
    subject { build(:user) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:name) }
  end

  describe "アソシエーション" do
    it { is_expected.to have_many(:sake_logs).dependent(:destroy) }
  end

  describe "メールアドレス確認(confirmable)" do
    describe "新規登録時" do
      # User に :confirmable が付いていること検証
      it "確認メールが1通送信される" do
        expect { create(:user, :unconfirmed) }.to change { ActionMailer::Base.deliveries.size }.by(1)
      end

      # allow_unconfirmed_access_for = 0.days（猶予なし）の検証
      it "確認が済むまではログインできず、確認するとログインできる" do
        user = create(:user, :unconfirmed)
        expect(user.active_for_authentication?).to be false

        user.confirm
        expect(user.active_for_authentication?).to be true
      end
    end

    describe "メールアドレス変更時" do
      # reconfirmable = true を検証する
      it "確認が済むまでemailは変わらず、確認後に切り替わる" do
        user = create(:user, email: "before@example.com")
        user.update!(email: "after@example.com")
        expect(user.reload.email).to eq "before@example.com"
        expect(user.unconfirmed_email).to eq "after@example.com"

        user.confirm
        expect(user.reload.email).to eq "after@example.com"
      end
    end
  end

  describe "#own?" do
    let(:user) { create(:user) }

    it "自分の投稿なら true を返す" do
      sake_log = create(:sake_log, user: user)
      expect(user.own?(sake_log)).to be true
    end

    it "他人の投稿なら false を返す" do
      other_sake_log = create(:sake_log)
      expect(user.own?(other_sake_log)).to be false
    end

    it "引数が nil でも例外にならず false を返す" do
      expect(user.own?(nil)).to be false
    end
  end
end
