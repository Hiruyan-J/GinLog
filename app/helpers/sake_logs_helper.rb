module SakeLogsHelper
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
end
