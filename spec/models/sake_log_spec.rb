require 'rails_helper'

# == Schema Information
#
# Table name: sake_logs
#
#  id             :bigint           not null, primary key
#  aroma_strength :float            not null
#  rating         :integer          not null
#  review         :text
#  taste_strength :float            not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  sake_id        :bigint           not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_sake_logs_on_sake_id  (sake_id)
#  index_sake_logs_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (sake_id => sakes.id)
#  fk_rails_...  (user_id => users.id)
#
RSpec.describe SakeLog, type: :model do
  describe "バリデーション" do
    subject { build(:sake_log) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:rating) }
    it { is_expected.to validate_presence_of(:taste_strength) }
    it { is_expected.to validate_presence_of(:aroma_strength) }

    it "rating は下限・上限の境界内かつ整数のみ有効" do
      is_expected.to validate_numericality_of(:rating)
        .only_integer
        .is_greater_than_or_equal_to(SakeLog::RATING_MIN)
        .is_less_than_or_equal_to(SakeLog::RATING_MAX)
    end

    it "taste_strength は下限・上限の境界内のみ有効" do
      is_expected.to validate_numericality_of(:taste_strength)
        .is_greater_than_or_equal_to(SakeLog::TASTE_STRENGTH_MIN)
        .is_less_than_or_equal_to(SakeLog::TASTE_STRENGTH_MAX)
    end

    it "aroma_strength は下限・上限の境界内のみ有効" do
      is_expected.to validate_numericality_of(:aroma_strength)
        .is_greater_than_or_equal_to(SakeLog::AROMA_STRENGTH_MIN)
        .is_less_than_or_equal_to(SakeLog::AROMA_STRENGTH_MAX)
    end

    describe "review の文字数" do
      it { is_expected.to validate_length_of(:review).is_at_most(SakeLog::REVIEW_MAX_LENGTH) }

      it "空でも有効(任意項目)" do
        expect(build(:sake_log, review: "")).to be_valid
      end
    end
  end

  describe "アソシエーション" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:sake) }
  end

  describe "reviewの正規化" do
    it "前後の空白を除去して代入する" do
      sake_log = build(:sake_log, review: "  余韻が長い  ")

      expect(sake_log.review).to eq "余韻が長い"
    end
  end

  describe "ラベル画像" do
    let(:sake_log) { build(:sake_log) }

    # テスト用の小さな画像を Active Storage に渡せる形にする
    # 既定は正常系で使う PNG。異常系のテストだけ引数で差し替える
    # @param filename [String] spec/fixtures/files 配下のファイル名
    # @param content_type [String] 送信されたことにする Content-Type
    # @return [Rack::Test::UploadedFile]
    def uploaded_file(filename = "label.png", content_type = "image/png")
      Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files", filename),
        content_type
      )
    end

    it "画像を1枚も添付しなくても有効(すべて任意)" do
      expect(sake_log).to be_valid
    end

    it "4スロットそれぞれに添付できる" do
      SakeLog::IMAGE_ATTACHMENT_NAMES.each do |attachment_name|
        sake_log.public_send(attachment_name).attach(uploaded_file)
      end

      expect(sake_log).to be_valid
      expect(SakeLog::IMAGE_ATTACHMENT_NAMES).to all(satisfy { |name| sake_log.public_send(name).attached? })
    end

    context "許可されていない形式の場合" do
      it "無効になり、スロット名付きのエラーが入る" do
        sake_log.front_label_image.attach(uploaded_file("not_image.txt", "text/plain"))

        expect(sake_log).to be_invalid
        expect(sake_log.errors[:front_label_image]).to include("はJPEG・PNG・WebP・HEIC形式のみアップロードできます")
      end
    end

    context "上限サイズの境界値分析" do
      it "上限オーバー時。無効になり、スロット名付きのエラーが入る" do
        sake_log.front_label_image.attach(uploaded_file)
        # byte_size メソッドをスタブ化
        allow(sake_log.front_label_image.blob).to receive(:byte_size).and_return(SakeLog::IMAGE_MAX_SIZE + 1)

        expect(sake_log).to be_invalid
        expect(sake_log.errors[:front_label_image]).to include("は10MB以下にしてください")
      end

      it "ちょうど上限サイズなら有効" do
        sake_log.front_label_image.attach(uploaded_file)
        allow(sake_log.front_label_image.blob).to receive(:byte_size).and_return(SakeLog::IMAGE_MAX_SIZE)

        expect(sake_log).to be_valid
      end
    end

    describe "#attached_images" do
      it "添付済みのスロットだけを、定数の並び順で返す" do
        # sub_image2 を先に添付しても、IMAGE_ATTACHMENT_NAMES の順で返ることを確認する
        sake_log.sub_image2.attach(uploaded_file)
        sake_log.front_label_image.attach(uploaded_file)

        expect(sake_log.attached_images.map(&:first)).to eq %i[front_label_image sub_image2]
      end

      it "スロット名とセットで、そのスロットの添付を返す" do
        sake_log.front_label_image.attach(uploaded_file)

        attachment_name, attachment = sake_log.attached_images.first

        expect(attachment_name).to eq :front_label_image
        expect(attachment).to eq sake_log.front_label_image
        expect(attachment).to be_attached
      end

      it "1枚も添付がなければ空配列を返す" do
        expect(sake_log.attached_images).to be_empty
      end
    end
  end
end
