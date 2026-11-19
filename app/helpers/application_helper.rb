module ApplicationHelper
  # DeviseなどのflashタイプをDaisyUIのクラス名に変換する
  def flash_class_for(type)
    case type.to_s
    when "notice"
      "success"
    when "alert"
      "error"
    else
      type.to_s
    end
  end

  def page_heading(title = nil)
    render "shared/page_heading", title: title
  end

  def default_meta_tags
    {
      site: "吟ログ",
      title: content_for?(:title) ? content_for(:title) : "",
      reverse: false,
      charset: "utf-8",
      separator: "|",   # Webサイト名とページタイトルを区切るために使用されるテキスト
      description: "吟ログは、ラベルを撮るだけでAIが銘柄や蔵元を読み取ってくれる日本酒メモアプリ。好み度・味・香りを選ぶだけでサクッと記録でき、好きなフレーバーや産地の傾向も分析。初心者でも自分に合う日本酒が見つかります。",
      keywords: "日本酒, 日本酒アプリ, 日本酒メモ, 酒蔵, 銘柄検索, テイスティング記録, ラベル認識, 吟ログ",   # キーワードを「,」区切りで設定する
      canonical: request.original_url,   # 優先するurlを指定する
      noindex: ! Rails.env.production?,
      icon: [                    # favicon、apple用アイコンを指定する
        { href: image_url("ginlog_favicon.png"), sizes: "32x32" },
        { href: image_url("ginlog_app-icon.png"), rel: "apple-touch-icon", sizes: "180x180", type: "image/jpg" }
      ],
      og: {
        site_name: :site,
        title: :title,
        description: :description,
        type: "website",
        url: request.original_url,
        image: image_url("ginlog_ogp.png"),
        locale: "ja_JP"
      },
      twitter: {
        card: "summary_large_image"
      }
    }
  end
end
