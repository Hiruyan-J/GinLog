require 'rails_helper'

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  name                   :string           not null
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
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
