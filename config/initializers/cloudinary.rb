# Cloudinary の接続情報を credentials から読み込んで gem に渡す
# （gem が自動で読むのは環境変数 CLOUDINARY_URL のみのため）
cloudinary_url = Rails.application.credentials.dig(:cloudinary, :url)

# 保存先が Cloudinary なのに接続情報が無い場合は起動時に落とす。
# 素通りさせると、最初の画像アップロード・表示まで設定漏れに気づけない。
if Rails.application.config.active_storage.service.to_s == "cloudinary" &&
    ENV["SECRET_KEY_BASE_DUMMY"].blank? &&
    cloudinary_url.blank? && ENV["CLOUDINARY_URL"].blank?
  raise "Cloudinary の接続情報がありません。" \
        "credentialsに cloudinary.url を設定するか、" \
        "環境変数 CLOUDINARY_URL を指定してください。"
end

Cloudinary.config_from_url(cloudinary_url) if cloudinary_url.present?
