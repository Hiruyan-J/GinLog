require 'rails_helper'

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
