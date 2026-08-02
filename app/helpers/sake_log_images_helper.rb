# 日本酒記録のラベル画像を表示するためのヘルパー
#
# 画像のリサイズは Rails 側（Active Storage の variant）ではなく、
# Cloudinary の URL 変換に任せている。
# そのため image_processing gem と libvips が不要で、
# 元が2MBのスマホ写真でも数十KBで配信でき、無料枠の転送量を節約できる。
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
  # 渡した引数は Cloudinary によって URL 内の変換パラメータに変換される。
  # 例)
  #   width: 300         -> w_300   … 幅300pxに縮小
  #   crop: :limit       -> c_limit … 指定幅以内に収める（元より拡大しない）
  #   fetch_format: :auto-> f_auto  … 対応ブラウザには WebP / AVIF で配信
  #   quality: :auto     -> q_auto  … 見た目を保ちつつ自動で圧縮
  # 生成例: https://res.cloudinary.com/<cloud_name>/image/upload/c_limit,f_auto,q_auto,w_300/<key>
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
