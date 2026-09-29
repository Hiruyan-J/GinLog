# 日本酒記録のラベル画像を表示するためのヘルパー
#
# 画像のリサイズは Rails 側（Active Storage の variant）ではなく、
# Cloudinary の URL 変換に任せている。
# そのため image_processing gem と libvips が不要で、
# 元が2MBのスマホ写真でも数十KBで配信でき、無料枠の転送量を節約できる。
module SakeLogImagesHelper
  # ラベル写真が無い記録で使う土台画像
  OGP_BASE_PUBLIC_ID = "ginlog_ogp_base".freeze
  OGP_FONT_FAMILY = "Sawarabi Gothic".freeze
  # 静的OGP画像に合わせたクリーム色（写真の余白を埋める）
  OGP_BACKGROUND_COLOR = "#F7F3EA".freeze
  OGP_TEXT_X = 64
  OGP_TEXT_WIDTH = 580

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

  # 記録詳細の OGP 画像（X のカードに出る画像）の URL を返す
  #
  # 画像は保存せず、Cloudinary の URL 変換でその都度作る。
  # 銘柄名・商品名・蔵元名・好み度が URL に含まれるので、記録を編集すると URL も変わり、最新の画像になる。
  # X のクローラーは WebP / AVIF を読めないことがあるため、f_auto ではなく jpg で固定する。
  #
  # @param sake_log [SakeLog] OGP 画像を作る記録
  # @return [String] OGP 画像の絶対 URL
  def sake_log_ogp_image_url(sake_log)
    return image_url("ginlog_ogp.png") unless cloudinary_storage?

    # 表ラベル → 裏ラベル → サブ画像の順で、最初に見つかった画像を使う
    _attachment_name, attachment = sake_log.attached_images.first
    public_id = attachment ? attachment.blob.key : OGP_BASE_PUBLIC_ID

    url = cloudinary_url(public_id, secure: true, format: "jpg",
                                    transformation: sake_log_ogp_transformation(sake_log))
    # フォント名の空白（Sawarabi Gothic）がそのまま URL に入ってしまうため、空白を %20 に置き換える
    url.gsub(" ", "%20")
  end

  private

  # Active Storage の保存先が Cloudinary かどうか
  # （テスト環境では Disk のままなので false になる）
  def cloudinary_storage?
    defined?(ActiveStorage::Service::CloudinaryService) &&
      ActiveStorage::Blob.service.is_a?(ActiveStorage::Service::CloudinaryService)
  end

  # OGP 画像の変換内容を返す
  #
  # @param sake_log [SakeLog] OGP 画像を作る記録
  # @return [Array<Hash>] cloudinary_url の transformation に渡す配列
  def sake_log_ogp_transformation(sake_log)
    [
      { width: 520, height: 630, crop: :pad, background: OGP_BACKGROUND_COLOR },
      { width: 1200, height: 630, crop: :pad, gravity: :east, background: OGP_BACKGROUND_COLOR },
      ogp_text_layer("吟ログ", size: 36, color: "#5B8C6F", y: 56, bold: true),
      # 銘柄名は1行に収めるため8文字で切る（72px × 8文字 ≒ 580px）
      ogp_text_layer(sake_log.sake.brand.name.truncate(8, omission: "…"), size: 72, color: "#333333", y: 200, bold: true),
      # 商品名は折り返して2行までに収める（48px × 12文字 ≒ 580px で1行）
      ogp_text_layer(sake_log.sake.product_name.truncate(24, omission: "…"), size: 48, color: "#555555", y: 310),
      # 蔵元名は1行に収める（商品名2行の下。36px × 16文字 ≒ 580px で1行）
      ogp_text_layer(ogp_brewery_label(sake_log.sake.brand.brewery), size: 36, color: "#777777", y: 450),
      # 好み度は左下に置く（下端から 64px）
      ogp_text_layer("★" * sake_log.rating + "☆" * (SakeLog::RATING_MAX - sake_log.rating),
                     size: 48, color: "#E0A800", y: 64, gravity: :south_west)
    ]
  end

  # OGP 画像に載せる「(蔵元名 - 都道府県名)」を返す
  #
  # 蔵元名が「(名称不明)」のようにカッコ書きだけのときは、蔵元名を省いて「(都道府県名)」にする。
  # 1行に収めるように、長い蔵元名は蔵元名だけを10文字で切る。
  #
  # @param brewery [Brewery] 銘柄の蔵元
  # @return [String] 例: "(浜川商店 - 高知県)"
  def ogp_brewery_label(brewery)
    brewery_name = brewery.name.match?(/\A[(（].*[)）]\z/) ? nil : brewery.name.truncate(10, omission: "…")
    "(#{[ brewery_name, brewery.area.name ].compact.join(' - ')})"
  end

  # 文字を重ねる変換（Cloudinary のテキストレイヤー）を1つ返す
  #
  # カンマ・スラッシュなど URL で特別な意味を持つ文字は、cloudinary gem がエスケープしてくれる。
  #
  # @param text [String] 重ねる文字
  # @param size [Integer] 文字の大きさ(px)
  # @param color [String] 文字色（"#RRGGBB"）
  # @param y [Integer] gravity の基準位置からの縦のずれ(px)
  # @param gravity [Symbol] 配置の基準（:north_west = 左上 / :south_west = 左下）
  # @param bold [Boolean] 太字にするか
  # @return [Hash] transformation の1要素
  def ogp_text_layer(text, size:, color:, y:, gravity: :north_west, bold: false)
    {
      overlay: { font_family: OGP_FONT_FAMILY, font_size: size, font_weight: (bold ? :bold : nil), text: text }.compact,
      color: color, gravity: gravity, x: OGP_TEXT_X, y: y,
      # 幅を超えたら折り返す
      width: OGP_TEXT_WIDTH, crop: :fit
    }
  end
end
