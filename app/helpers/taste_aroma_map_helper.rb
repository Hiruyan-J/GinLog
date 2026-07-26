# 味 × 香りの4象限マップ（shared/_taste_aroma_map）の表示ロジックをまとめたヘルパー。
# 「どの象限に属するか」の判定と「象限セルの CSS クラス」を提供する。
#
# SakeLog（taste_strength / aroma_strength）と
# Sake（average_taste_strength / average_aroma_strength）で同じ判定を使用
module TasteAromaMapHelper
  # 象限判定の境界値。この値以上なら右側（味が濃い）・上側（香りが華やか）に分類する
  QUADRANT_BOUNDARY = 5.0

  # 各象限に適用する Tailwind CSS クラス
  # active（活性象限）: 濃い背景 + 実線枠 / inactive（非活性象限）: 薄い背景 + 破線枠
  QUADRANT_STYLES = {
    # 左上: 香り華やか × 味スッキリ
    aroma_high_taste_light: { active: "bg-green-200 border-green-400 border-solid", inactive: "bg-green-50 border-green-200 border-dashed" },
    # 右上: 香り華やか × 味濃い
    aroma_high_taste_strong: { active: "bg-red-200 border-red-400 border-solid", inactive: "bg-red-50 border-red-200 border-dashed" },
    # 左下: 香り穏やか × 味スッキリ
    aroma_low_taste_light: { active: "bg-sky-300 border-sky-400 border-solid", inactive: "bg-sky-50 border-sky-200 border-dashed" },
    # 右下: 香り穏やか × 味濃い
    aroma_low_taste_strong: { active: "bg-amber-200 border-amber-400 border-solid", inactive: "bg-amber-50 border-amber-200 border-dashed" }
  }.freeze

  # 4象限マップの外枠サイズ(幅)のプリセット
  QUADRANT_MAP_SIZES = {
    sm: "w-16 md:w-24",  # 一覧カード（マイログ / タイムライン）
    md: "w-48 md:w-56", # 中間サイズ
    lg: "w-64 md:w-80"  # 詳細画面など広い画面
  }.freeze

  # 味・香りの値から4象限マップのどの象限に属するかを判定する
  # 味（横軸）: 5.0 未満は light（スッキリ）/ 5.0 以上は strong（濃い）
  # 香り（縦軸）: 5.0 未満は low（穏やか）/ 5.0 以上は high（華やか）
  #
  # @param taste_strength [Float] 味の濃淡（SakeLog#taste_strength / Sake#average_taste_strength）
  # @param aroma_strength [Float] 香りの濃淡（SakeLog#aroma_strength / Sake#average_aroma_strength）
  # @return [Symbol] 象限のキー
  def taste_aroma_quadrant(taste_strength, aroma_strength)
    aroma_level = aroma_strength >= QUADRANT_BOUNDARY ? "high" : "low"
    taste_level = taste_strength >= QUADRANT_BOUNDARY ? "strong" : "light"
    :"aroma_#{aroma_level}_taste_#{taste_level}"
  end

  # 4象限マップの1象限分の Tailwind CSS クラスを返す
  # 描画対象の象限が活性象限と一致すれば active、それ以外は inactive のクラスを返す
  #
  # @param quadrant [Symbol] 描画対象の象限キー
  # @param active_quadrant [Symbol, nil] 活性化する象限のキー (nil なら全象限が非活性)
  # @return [String] Tailwind CSS クラス文字列
  def quadrant_cell_class(quadrant, active_quadrant)
    state = quadrant == active_quadrant ? :active : :inactive
    QUADRANT_STYLES.fetch(quadrant).fetch(state)
  end

  # 4象限マップの軸ラベルに付ける表示クラスを返す
  # :responsive はスマホ（md 未満）で非表示・md 以上で表示（一覧のコンパクト表示）
  # :always は常に表示（詳細画面などスペースが十分な画面用・デフォルト）
  #
  # @param display_mode [Symbol] ラベルの表示方式（:always = 常に表示 / :responsive = スマホで非表示）
  # @return [String] Tailwind CSS クラス文字列（:always のときは空文字）
  def quadrant_label_class(display_mode)
    display_mode == :responsive ? "hidden md:block" : ""
  end

  # 4象限マップの外枠に付ける幅クラスを返す
  # 呼び出し側は用途名(:sm / :md / :lg)でサイズ指定可能
  #
  # @param size [Symbol] サイズ名（:sm = 一覧カード / :md = 中 / :lg = 詳細画面）
  # @return [String] Tailwind CSS の幅クラス
  def quadrant_map_size_class(size)
    QUADRANT_MAP_SIZES.fetch(size)
  end

  # 点プロット（variant: :plot）で打つ点の位置を style 属性の文字列として返す
  # 味（横軸）は左から右へ、香り（縦軸）は下から上へ値が大きくなるように配置する。
  #
  # @param taste_strength [Float] 味の濃淡（0〜10）
  # @param aroma_strength [Float] 香りの濃淡（0〜10）
  # @return [String] style 属性に渡す文字列（例: "left: 30.0%; top: 80.0%;"）
  def quadrant_plot_point_style(taste_strength, aroma_strength)
    left_percent = (taste_strength.to_f / SakeLog::TASTE_STRENGTH_MAX * 100).round(1)
    top_percent = ((1 - aroma_strength.to_f / SakeLog::AROMA_STRENGTH_MAX) * 100).round(1)
    "left: #{left_percent}%; top: #{top_percent}%;"
  end
end
