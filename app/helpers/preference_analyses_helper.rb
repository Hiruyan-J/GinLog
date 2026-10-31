# 好み分析画面（産地別分析の都道府県タイルマップ）の表示ロジックをまとめたヘルパー
module PreferenceAnalysesHelper
  # 都道府県名 => [行, 列, 縦のマス数, 横のマス数]（行・列は1始まり）。28列 × 25行のグリッドに日本の形で並べる
  PREFECTURE_TILE_POSITIONS = {
    "北海道" => [ 1, 24, 4, 5 ], "青森県" => [ 5, 24, 2, 4 ],
    "秋田県" => [ 7, 24, 2, 2 ], "岩手県" => [ 7, 26, 2, 2 ],
    "山形県" => [ 9, 24, 2, 2 ], "宮城県" => [ 9, 26, 2, 2 ], "福島県" => [ 11, 24, 2, 4 ],
    "茨城県" => [ 13, 26, 3, 2 ], "栃木県" => [ 13, 24, 2, 2 ], "群馬県" => [ 13, 22, 2, 2 ],
    "埼玉県" => [ 15, 22, 2, 4 ], "千葉県" => [ 16, 26, 3, 2 ],
    "東京都" => [ 17, 24, 2, 2 ], "神奈川県" => [ 19, 23, 2, 3 ],
    "新潟県" => [ 11, 21, 2, 3 ], "富山県" => [ 11, 18, 2, 3 ], "石川県" => [ 9, 16, 4, 2 ], "福井県" => [ 13, 16, 2, 2 ],
    "山梨県" => [ 17, 22, 2, 2 ], "長野県" => [ 13, 20, 6, 2 ], "岐阜県" => [ 13, 18, 6, 2 ],
    "静岡県" => [ 19, 20, 2, 3 ], "愛知県" => [ 19, 18, 2, 2 ],
    "三重県" => [ 19, 16, 4, 2 ], "滋賀県" => [ 15, 16, 4, 2 ], "京都府" => [ 13, 14, 6, 2 ], "兵庫県" => [ 13, 12, 6, 2 ],
    "大阪府" => [ 19, 12, 2, 2 ], "奈良県" => [ 19, 14, 2, 2 ], "和歌山県" => [ 21, 12, 2, 4 ],
    "鳥取県" => [ 13, 10, 2, 2 ], "島根県" => [ 13, 8, 2, 2 ], "岡山県" => [ 15, 10, 2, 2 ], "広島県" => [ 15, 8, 2, 2 ], "山口県" => [ 13, 6, 4, 2 ],
    "香川県" => [ 18, 10, 2, 2 ], "愛媛県" => [ 18, 8, 2, 2 ], "徳島県" => [ 20, 10, 2, 2 ], "高知県" => [ 20, 8, 2, 2 ],
    "福岡県" => [ 18, 3, 2, 3 ], "佐賀県" => [ 18, 1, 2, 2 ], "長崎県" => [ 20, 1, 2, 2 ], "熊本県" => [ 20, 3, 4, 2 ],
    "大分県" => [ 20, 5, 2, 2 ], "宮崎県" => [ 22, 5, 2, 2 ], "鹿児島県" => [ 24, 3, 2, 4 ], "沖縄県" => [ 10, 1, 2, 2 ]
  }.freeze

  # 沖縄を囲む ┘ 形の線の位置 [行, 列, 縦のマス数, 横のマス数]
  OKINAWA_FRAME_POSITION = [ 9, 1, 4, 3 ].freeze

  # 平均好み度の5段階（0以上1未満 / 1以上2未満 / … / 4以上5以下）の色と凡例の文字
  RATING_LEVELS = [
    { label: "0〜", tile_class: "bg-emerald-100 text-emerald-900" },
    { label: "1〜", tile_class: "bg-emerald-200 text-emerald-900" },
    { label: "2〜", tile_class: "bg-emerald-300 text-emerald-900" },
    { label: "3〜", tile_class: "bg-emerald-500 text-white" },
    { label: "4〜5", tile_class: "bg-emerald-700 text-white" }
  ].freeze

  # 記録のない都道府県の色
  NO_RECORD_TILE_CLASS = "bg-neutral-200 text-neutral-400".freeze

  # 一番好きな都道府県に付ける強調（枠）
  BEST_TILE_CLASS = "ring-2 ring-amber-400 font-bold".freeze

  # タイルの位置（style 属性の文字列）を返す
  # @param area [Area] 都道府県
  # @return [String, nil] 例: "grid-row: 11 / span 2; grid-column: 21 / span 3;"（表にない名前なら nil）
  def prefecture_tile_style(area)
    position = PREFECTURE_TILE_POSITIONS[area.name]
    grid_area_style(*position) if position
  end

  # 沖縄を囲む線の位置（style 属性の文字列）を返す
  # @return [String] 例: "grid-row: 9 / span 4; grid-column: 1 / span 3;"
  def okinawa_frame_style
    grid_area_style(*OKINAWA_FRAME_POSITION)
  end

  # タイルに書く短い名前（末尾の 都・府・県 を除いた名前）を返す
  # @param area [Area] 都道府県
  # @return [String] 例: "新潟県" → "新潟" / "北海道" → "北海道" / "和歌山県" → "和歌山"
  def prefecture_tile_label(area)
    area.name.sub(/[都府県]\z/, "")
  end

  # タイルの色（と、一番好きな都道府県なら強調）のクラスを返す
  # @param stat [PreferenceAnalysis::Stat, nil] その都道府県の集計結果（記録がなければ nil）
  # @param best [Boolean] 一番好きな都道府県かどうか
  # @return [String] Tailwind CSS クラス文字列
  def prefecture_tile_class(stat, best)
    color_class = stat ? RATING_LEVELS[rating_level_index(stat.average)][:tile_class] : NO_RECORD_TILE_CLASS
    best ? "#{color_class} #{BEST_TILE_CLASS}" : color_class
  end

  # タイルにマウスを乗せたときに出す説明（title 属性）を返す
  # @param area [Area] 都道府県
  # @param stat [PreferenceAnalysis::Stat, nil] その都道府県の集計結果（記録がなければ nil）
  # @return [String] 例: "新潟県：平均 4.0（3件）" / "新潟県：未記録"
  def prefecture_tile_title(area, stat)
    return "#{area.name}：未記録" unless stat

    "#{area.name}：平均 #{number_with_precision(stat.average, precision: 1)}（#{stat.count}件）"
  end

  private

  # グリッド上の位置と大きさを style 属性の文字列にする
  # @param row [Integer] 行（1始まり）
  # @param column [Integer] 列（1始まり）
  # @param row_span [Integer] 縦のマス数
  # @param column_span [Integer] 横のマス数
  # @return [String] 例: "grid-row: 11 / span 2; grid-column: 21 / span 3;"
  def grid_area_style(row, column, row_span, column_span)
    "grid-row: #{row} / span #{row_span}; grid-column: #{column} / span #{column_span};"
  end

  # 平均好み度が5段階のどれに入るか（0始まり）。5.0 は一番上の段階に入れる
  # @param average [Float] 平均好み度（0〜5）
  # @return [Integer] 0〜4
  def rating_level_index(average)
    [ average.floor, RATING_LEVELS.size - 1 ].min
  end
end
