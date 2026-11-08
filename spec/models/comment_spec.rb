require 'rails_helper'

RSpec.describe Comment, type: :model do
  describe "バリデーション" do
    subject { build(:comment) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:body) }
    it { is_expected.to validate_length_of(:body).is_at_most(Comment::BODY_MAX_LENGTH) }
  end

  describe "本文の正規化" do
    it "前後の空白・改行を取り除く" do
      expect(build(:comment, body: "  おいしい\n").body).to eq "おいしい"
    end

    it "空白だけの本文は空として扱い、保存できない" do
      expect(build(:comment, body: " 　\n")).not_to be_valid
    end
  end

  describe "#edited?" do
    let!(:comment) { create(:comment, body: "編集前") }

    it "投稿したままなら false" do
      expect(comment.edited?).to be false
    end

    it "本文を編集すると true" do
      travel_to(1.minute.from_now) { comment.update!(body: "編集後") }

      expect(comment.edited?).to be true
    end

    it "同じ本文で保存し直しても false" do
      travel_to(1.minute.from_now) { comment.update!(body: "編集前") }

      expect(comment.edited?).to be false
    end
  end

  describe "関連先の削除" do
    let!(:comment) { create(:comment) }

    it "記録を削除するとコメントも削除される" do
      expect { comment.sake_log.destroy }.to change(described_class, :count).by(-1)
    end

    it "ユーザーを削除するとコメントも削除される" do
      expect { comment.user.destroy }.to change(described_class, :count).by(-1)
    end
  end
end
