# 味 × 香りの4象限の判定ルール（境界値と各象限の条件）
# 4象限マップの表示・日本酒の4象限検索・好み分析で共通に使う
module TasteAromaQuadrant
  # 境界値。この値以上なら右側（味が濃い）・上側（香りが華やか）に分類する
  BOUNDARY = 5.0

  # 象限キー => 香り・味を境界値と比べる方法（gteq = 以上 / lt = 未満）
  # 並びは 左上 → 右上 → 左下 → 右下（2×2 グリッドに描く順番）
  CONDITIONS = {
    "aroma_high_taste_light" => { aroma: :gteq, taste: :lt },
    "aroma_high_taste_strong" => { aroma: :gteq, taste: :gteq },
    "aroma_low_taste_light" => { aroma: :lt, taste: :lt },
    "aroma_low_taste_strong" => { aroma: :lt, taste: :gteq }
  }.freeze

  # 象限キーの一覧（URL パラメータの受け付けや、象限を順に並べるときに使う）
  KEYS = CONDITIONS.keys.freeze

  # 香り・味の値から象限キーを返す
  # @param aroma_strength [Float] 香りの濃淡（0〜10）
  # @param taste_strength [Float] 味の濃淡（0〜10）
  # @return [String] 象限キー（例: "aroma_high_taste_light"）
  def self.key_for(aroma_strength:, taste_strength:)
    aroma_level = aroma_strength >= BOUNDARY ? "high" : "low"
    taste_level = taste_strength >= BOUNDARY ? "strong" : "light"
    "aroma_#{aroma_level}_taste_#{taste_level}"
  end

  # 1象限分の SQL の条件式（例: 香り >= 5.0 AND 味 < 5.0）を作る
  # カラムを引数で受け取るので、sakes の平均値にも sake_logs の記録値にも使える
  # @param quadrant [String] 象限キー（KEYS のどれか）
  # @param aroma_column [Arel::Attributes::Attribute] 香りのカラム（例: Sake.arel_table[:average_aroma_strength]）
  # @param taste_column [Arel::Attributes::Attribute] 味のカラム（例: Sake.arel_table[:average_taste_strength]）
  # @return [Arel::Nodes::And] 「香りの条件 AND 味の条件」の式
  def self.condition(quadrant, aroma_column:, taste_column:)
    operators = CONDITIONS.fetch(quadrant)
    aroma_condition = aroma_column.public_send(operators[:aroma], BOUNDARY)
    taste_condition = taste_column.public_send(operators[:taste], BOUNDARY)
    aroma_condition.and(taste_condition)
  end
end
