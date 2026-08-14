module SakeLogsHelper
  # 記録詳細でラベル画像を横スクロールに切り替える枚数
  #   1〜2枚は並べて全部見えるが、3枚以上は並べると1枚が小さくなりすぎるため横スクロールにする
  DETAIL_CAROUSEL_THRESHOLD = 3

  # 横スクロール時の画像1枚あたりの幅
  #   画面幅 100% ÷ 2.2枚 ≒ 45% にすると3枚目が右端で見切れ、
  #   「まだ続きがある」とユーザーが気づける
  DETAIL_CAROUSEL_ITEM_WIDTH = "w-[45%]".freeze

  # 好み度の星色を返すヘルパー
  # RustyWind(Tailwind くらすソーター)がERBの三項演算子 `?` を壊すバグ (Issue #124) を回避するため、
  # ビュー内のインライン三項演算子をヘルパーメソッドに切り出している
  #
  # @param rate [Integer] 現在の星のインデックス(0始まり)
  # @param rating [Integer] 記録された好み度
  # @return [String] Tailwind CSS の背景色クラス
  def star_rating_class(rate, rating)
    rate < rating ? "bg-yellow-300" : "bg-stone-400"
  end

  # 記録詳細のラベル画像を横スクロールで見せるかどうか
  #
  # @param image_count [Integer] 添付されているラベル画像の枚数
  # @return [Boolean] 3枚以上なら true
  def sake_log_detail_carousel?(image_count)
    image_count >= DETAIL_CAROUSEL_THRESHOLD
  end

  # ラベル画像を並べる入れ物（親要素）のクラスを返す
  #
  #   1枚    … 中央寄せで1枚（横幅いっぱいだと大きくなりすぎるため max-w-sm で抑える）
  #   2枚    … 2列に並べる
  #   3〜4枚 … DaisyUI の carousel で横スクロール
  #
  # @param image_count [Integer] 添付されているラベル画像の枚数
  # @return [String] Tailwind CSS / DaisyUI のクラス
  def sake_log_detail_images_class(image_count)
    return "flex overflow-x-auto gap-2 w-full snap-x carousel" if sake_log_detail_carousel?(image_count)
    return "grid grid-cols-2 gap-2" if image_count == 2

    "grid grid-cols-1 mx-auto max-w-sm"
  end

  # ラベル画像1枚分（figure）のクラスを返す
  #
  # 横スクロール時だけ carousel-item を付ける。
  # carousel-item は display:flex なので、画像とキャプションを縦に積むため flex-col も添える。
  #
  # @param image_count [Integer] 添付されているラベル画像の枚数
  # @return [String] Tailwind CSS / DaisyUI のクラス（並べて表示するときは空文字）
  def sake_log_detail_image_class(image_count)
    return "carousel-item flex-col shrink-0 #{DETAIL_CAROUSEL_ITEM_WIDTH}" if sake_log_detail_carousel?(image_count)

    ""
  end

  # 記録詳細の「戻る」リンクの文言と遷移先を返す
  #
  # 遷移元（from）が分かるときはその一覧へ戻す。
  # 直リンクや検索エンジン経由で from が無いときは、
  # 自分の記録ならマイログ、他人の記録ならタイムラインへ戻す。
  #
  # @param origin [String, nil] 遷移元（"timeline" / "mylog"）
  # @param owned [Boolean, nil] 表示中の記録がログイン中のユーザーのものか
  # @return [Array(String, String)] [リンクの文言, 遷移先のパス]
  def sake_log_back_link(origin:, owned:)
    case origin
    when "timeline" then [ "タイムラインに戻る", timeline_path ]
    when "mylog"    then [ "マイログに戻る", sake_logs_path ]
    else
      owned ? [ "マイログに戻る", sake_logs_path ] : [ "タイムラインに戻る", timeline_path ]
    end
  end
end
