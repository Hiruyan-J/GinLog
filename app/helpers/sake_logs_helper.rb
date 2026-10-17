module SakeLogsHelper
  # 記録詳細でラベル画像を横スクロールに切り替える枚数
  #   1〜2枚は並べて全部見えるが、3枚以上は並べると1枚が小さくなりすぎるため横スクロールにする
  DETAIL_CAROUSEL_THRESHOLD = 3

  # 横スクロール時の画像1枚あたりの幅
  #   画面幅 100% ÷ 2.2枚 ≒ 45% にすると3枚目が右端で見切れ、
  #   「まだ続きがある」とユーザーが気づける
  DETAIL_CAROUSEL_ITEM_WIDTH = "w-[45%]".freeze

  # 好み度の星（0.5 刻み）で使う、半分の星1個あたりの大きさ（幅は高さの半分）
  HALF_STAR_SIZES = {
    sm: "w-1.5 h-3 md:w-2 md:h-4", # 一覧（検索結果）
    lg: "w-2.5 h-5"                # 詳細画面
  }.freeze

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

  # 好み度で点灯させる「半分の星」の個数を返す（0.5 刻みに四捨五入）
  #
  # @param rating [Numeric] 好み度（記録の値、または平均。例: 3.4）
  # @return [Integer] 点灯させる半分の星の個数（例: 3.4 → 7 = 星 3 個半）
  def lit_half_star_count(rating)
    (rating * 2).round
  end

  # 半分の星1個分の CSS クラス（左右どちらの半分か・大きさ・色）を返す
  #
  # @param index [Integer] 半分の星のインデックス（0始まり。偶数が左半分、奇数が右半分）
  # @param lit_count [Integer] 点灯させる半分の星の個数（lit_half_star_count の戻り値）
  # @param size [Symbol] 星の大きさ（:sm = 一覧 / :lg = 詳細画面）
  # @return [String] Tailwind CSS / daisyUI のクラス文字列
  def half_star_class(index, lit_count, size)
    half_class = index.even? ? "mask-half-1" : "mask-half-2"
    "#{half_class} #{HALF_STAR_SIZES.fetch(size)} #{star_rating_class(index, lit_count)}"
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
  # 遷移元（from）が分かるときはその画面へ戻す。
  # 直リンクや検索エンジン経由で from が無いときは、
  # 自分の記録ならマイログ、他人の記録ならタイムラインへ戻す。
  #
  # @param origin [String, nil] 遷移元（"timeline" / "mylog" / "sake"）
  # @param owned [Boolean, nil] 表示中の記録がログイン中のユーザーのものか
  # @param sake_id [Integer] 表示中の記録に紐づく sake の ID（from=sake の戻り先に使う）
  # @return [Array(String, String)] [リンクの文言, 遷移先のパス]
  def sake_log_back_link(origin:, owned:, sake_id:)
    case origin
    when "timeline" then [ "タイムラインに戻る", timeline_path ]
    when "mylog"    then [ "マイログに戻る", sake_logs_path ]
    when "sake"     then [ "日本酒詳細に戻る", sake_path(sake_id) ]
    else
      owned ? [ "マイログに戻る", sake_logs_path ] : [ "タイムラインに戻る", timeline_path ]
    end
  end
end
