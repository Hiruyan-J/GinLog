# 日本酒記録のラベル画像を表示するためのヘルパー
#
# Cloudinary を使っているときは、URL に変換パラメータを付けて
# 「CDN側でリサイズ済みの画像」を受け取る。
#   w_400        … 幅400pxに縮小
#   f_auto       … ブラウザが対応していれば WebP / AVIF で配信
#   q_auto       … 見た目を保ちつつ自動で圧縮
# これにより、元が2MBのスマホ写真でも数十KBで表示でき、無料枠の転送量を節約できる。
module SakeLogImagesHelper
  # ラベル画像の img タグを返す
  #
  # @param attachment [ActiveStorage::Attached::One, nil] 表示対象の添付
  # @param width [Integer] 配信する画像の幅(px)
  # @param options [Hash] img タグに渡す追加属性（class, data など）
  # @return [String, nil] img タグ。未添付なら nil
  def sake_log_image_tag(attachment, width:, **options)
    url = sake_log_image_url(attachment, width: width)
    return nil if url.nil?

    image_tag(url, **options)
  end

  # ラベル画像の配信URLを返す（サムネイルから原寸を開くリンク用）
  #
  # @param attachment [ActiveStorage::Attached::One, nil] 表示対象の添付
  # @param width [Integer] 配信する画像の幅(px)
  # @return [String, nil] 画像のURL。未添付なら nil
  def sake_log_image_url(attachment, width:)
    return nil if attachment.blank?

    if cloudinary_storage?
      cloudinary_url(attachment.blob.key,
                      width: width, crop: :limit,
                      fetch_format: :auto, quality: :auto)
    else
      url_for(attachment)
    end
  end

  private

  # Active Storage の保存先が Cloudinary かどうか
  # （テスト環境では Disk のままなので false になる）
  def cloudinary_storage?
    defined?(ActiveStorage::Service::CloudinaryService) &&
      ActiveStorage::Blob.service.is_a?(ActiveStorage::Service::CloudinaryService)
  end
end
