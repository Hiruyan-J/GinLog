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
class SakeLog < ApplicationRecord
  RATING_MIN = 0
  RATING_MAX = 5
  TASTE_STRENGTH_MIN = 0
  TASTE_STRENGTH_MAX = 10
  TASTE_STRENGTH_DEFAULT = 5.0
  AROMA_STRENGTH_MIN = 0
  AROMA_STRENGTH_MAX = 10
  AROMA_STRENGTH_DEFAULT = 5.0
  REVIEW_MAX_LENGTH = 65_535
  IMAGE_ATTACHMENT_NAMES = %i[front_label_image back_label_image sub_image1 sub_image2].freeze
  IMAGE_MAX_SIZE = 10.megabytes
  IMAGE_CONTENT_TYPES = %w[image/jpeg image/png image/webp image/heic image/heif].freeze

  normalizes :review, with: ->(value) { value.strip }

  belongs_to :user
  belongs_to :sake

  has_one_attached :front_label_image
  has_one_attached :back_label_image
  has_one_attached :sub_image1
  has_one_attached :sub_image2

  validates :rating, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: RATING_MIN, less_than_or_equal_to: RATING_MAX }
  validates :taste_strength, presence: true, numericality: { greater_than_or_equal_to: TASTE_STRENGTH_MIN, less_than_or_equal_to: TASTE_STRENGTH_MAX }
  validates :aroma_strength, presence: true, numericality: { greater_than_or_equal_to: AROMA_STRENGTH_MIN, less_than_or_equal_to: AROMA_STRENGTH_MAX }
  validates :review, length: { maximum: REVIEW_MAX_LENGTH }, allow_blank: true
  validate :validate_images

  # 添付済みのラベル画像だけを [スロット名, 添付] の配列で返す
  # @return [Array<Array(Symbol, ActiveStorage::Attached::One)>] 例: [[:front_label_image, <Attached::One>]]
  def attached_images
    IMAGE_ATTACHMENT_NAMES.filter_map do |attachment_name|
      attachment = public_send(attachment_name)
      [ attachment_name, attachment ] if attachment.attached?
    end
  end

  private

  # 添付された画像すべての形式・サイズを検証する
  # @return [void]
  def validate_images
    IMAGE_ATTACHMENT_NAMES.each do |attachment_name|
      attachment = public_send(attachment_name)
      next unless attachment.attached?

      validate_image_content_type(attachment_name, attachment.blob)
      validate_image_size(attachment_name, attachment.blob)
    end
  end

  # 画像形式が許可リストに含まれるかを検証
  # @param attachment_name [Symbol] スロット名(:front_label_imageなど)
  # @param blob [ActiveStorage::Blob] 検証対象のファイル情報
  # @return [void]
  def validate_image_content_type(attachment_name, blob)
    return if IMAGE_CONTENT_TYPES.include?(detected_content_type(attachment_name, blob))

    errors.add(attachment_name, "はJPEG・PNG・WebP・HEIC・HEIF形式のみアップロードできます")
  end

  # 添付ファイルの実際の形式を返す
  #
  # @param attachment_name [Symbol] スロット名（:front_label_image など）
  # @param blob [ActiveStorage::Blob] 検証対象のファイル情報
  # @return [String] 例: "image/png"
  def detected_content_type(attachment_name, blob)
    attachable = attachment_changes[attachment_name.to_s]&.attachable
    # 新規添付以外（保存済みの添付など）は blob の値をそのまま使う
    return blob.content_type unless attachable.respond_to?(:read)

    Marcel::MimeType.for(attachable)
  end

  # 画像サイズが上限以内かを検証する
  # @param attachment_name [Symbol] スロット名（:front_label_image など）
  # @param blob [ActiveStorage::Blob] 検証対象のファイル情報
  # @return [void]
  def validate_image_size(attachment_name, blob)
    return if blob.byte_size <= IMAGE_MAX_SIZE

    errors.add(attachment_name, "は#{IMAGE_MAX_SIZE / 1.megabyte}MB以下にしてください")
  end
end
