# ユーザーの日本酒記録から好みを分析するクラス
# 集計テーブルは持たず、呼ばれるたびに sake_logs から集計する
class PreferenceAnalysis
  # 1つの区分（象限・都道府県）の集計結果
  # average: 平均好み度（0〜5） / count: 記録の件数
  Stat = Data.define(:average, :count)

  # @param user [User] 分析するユーザー
  def initialize(user)
    @sake_logs = user.sake_logs
  end

  # 記録が1件でもあるか
  # @return [Boolean]
  def any_logs?
    @sake_logs.exists?
  end

  # 4象限ごとの平均好み度と件数
  # @return [Hash{String => Stat}] 象限キー => 集計結果（記録のない象限はキーごと無い）
  def quadrant_stats
    @quadrant_stats ||= build_stats(@sake_logs.group(quadrant_case))
  end

  # 平均好み度が一番高い象限
  # 同点なら件数が多い方、それも同じなら TasteAromaQuadrant::KEYS の順（左上 → 右上 → 左下 → 右下）で先の方
  # @return [String, nil] 象限キー（記録が0件なら nil）
  def best_quadrant
    best = quadrant_stats.max_by do |quadrant, stat|
      [ stat.average, stat.count, -TasteAromaQuadrant::KEYS.index(quadrant) ]
    end
    best&.first
  end

  # 都道府県ごとの平均好み度と件数（「その他」は地図に描けないので除く）
  # @return [Hash{Integer => Stat}] 都道府県の ID => 集計結果（記録のない都道府県はキーごと無い）
  def area_stats
    @area_stats ||= build_stats(
      @sake_logs.joins(sake: { brand: { brewery: :area } })
                .where.not(areas: { sakenowa_id: Area::OTHER_SAKENOWA_ID })
                .group("areas.id")
    )
  end

  # 平均好み度が一番高い都道府県
  # 同点なら件数が多い方、それも同じなら北の方（sakenowa_id が小さい方）
  # @return [Area, nil] 都道府県（記録が0件なら nil）
  def best_area
    Area.where(id: area_stats.keys).max_by do |area|
      stat = area_stats[area.id]
      [ stat.average, stat.count, -area.sakenowa_id ]
    end
  end

  private

  # グループ分けした記録から、グループごとの平均好み度と件数を作る
  # @param grouped_logs [ActiveRecord::Relation<SakeLog>] group 済みの記録
  # @return [Hash{Object => Stat}] グループのキー => 集計結果
  def build_stats(grouped_logs)
    averages = grouped_logs.average(:rating)
    counts = grouped_logs.count
    averages.to_h { |key, average| [ key, Stat.new(average: average.to_f, count: counts[key]) ] }
  end

  # 記録の味・香りから象限キーを作る CASE 式
  # （例: CASE WHEN 香り >= 5.0 AND 味 < 5.0 THEN 'aroma_high_taste_light' WHEN ... END）
  # @return [Arel::Nodes::Case]
  def quadrant_case
    table = SakeLog.arel_table
    case_node = Arel::Nodes::Case.new

    TasteAromaQuadrant::KEYS.each do |quadrant|
      condition = TasteAromaQuadrant.condition(
        quadrant,
        aroma_column: table[:aroma_strength],
        taste_column: table[:taste_strength]
      )
      case_node.when(condition).then(quadrant)
    end

    case_node
  end
end
