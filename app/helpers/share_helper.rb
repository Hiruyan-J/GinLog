# X（旧Twitter）へのシェア用の URL・投稿文を組み立てるヘルパー
#
# X の Web Intent（https://x.com/intent/post?text=...&url=...）を使うため、
# API キーや gem は不要。リンクを開くと、文言が入力済みの投稿画面が表示される。
module ShareHelper
  X_INTENT_URL = "https://x.com/intent/post".freeze
  SHARE_HASHTAGS = %w[吟ログ 日本酒].freeze

  # X の投稿画面を開く URL を返す
  #
  # @param text [String] 投稿文
  # @param url [String] シェアするページの URL（絶対 URL）
  # @return [String] X の Web Intent の URL
  def x_share_url(text:, url:)
    query = URI.encode_www_form(text: text, url: url, hashtags: SHARE_HASHTAGS.join(","))
    "#{X_INTENT_URL}?#{query}"
  end

  # 記録（SakeLog）をシェアするときの投稿文を返す
  #
  # 投稿主は「飲みました」、それ以外（未ログインを含む）は「〇〇さんの記録」にする。
  #
  # @param sake_log [SakeLog] シェアする記録
  # @param owned [Boolean, nil] ログイン中のユーザーの記録か（未ログインなら nil）
  # @return [String] 投稿文
  def sake_log_share_text(sake_log, owned:)
    sake_name = "#{sake_log.sake.brand.name} #{sake_log.sake.product_name}"

    if owned
      "#{sake_name}を飲みました！"
    else
      "#{sake_log.user.name}さんの日本酒の記録「#{sake_name}」"
    end
  end

  # 日本酒詳細をシェアするときの投稿文を返す
  #
  # @param sake [Sake] シェアする日本酒
  # @return [String] 投稿文
  def sake_share_text(sake)
    "#{sake.brand.name} #{sake.product_name} のみんなの記録"
  end
end
