# タイムラインカード（timelines/_sake_log）の表示ロジックをまとめたヘルパー
#
# SakeLog の画像スロットは最大4枚だが、カードでは先頭2枚だけを並べ、
# 3枚目以降は枚数バッジ（+N）で知らせる。
# 全部見たい場合はカードをタップして記録詳細画面へ遷移してもらう。
module TimelinesHelper
  # タイムラインカードに並べるラベル画像の最大枚数
  CARD_IMAGE_LIMIT = 2

  # カードに並べる画像（先頭 CARD_IMAGE_LIMIT 枚）を返す
  #
  # @param attached_images [Array<Array(Symbol, ActiveStorage::Attached::One)>] SakeLog#attached_images の戻り値
  # @return [Array<Array(Symbol, ActiveStorage::Attached::One)>] カードに表示する分だけに絞った配列
  def timeline_card_images(attached_images)
    attached_images.first(CARD_IMAGE_LIMIT)
  end

  # カードに表示しきれなかった画像の枚数を返す
  #
  # @param attached_images [Array<Array(Symbol, ActiveStorage::Attached::One)>] SakeLog#attached_images の戻り値
  # @return [Integer] 表示しきれなかった枚数（すべて表示できていれば 0）
  def timeline_hidden_image_count(attached_images)
    [ attached_images.size - CARD_IMAGE_LIMIT, 0 ].max
  end

  # カード内の画像グリッドの列数クラスを返す
  # 画像が1枚だけのときは横幅いっぱいに、2枚のときは2列に並べる
  #
  # @param image_count [Integer] カードに表示する画像の枚数
  # @return [String] Tailwind CSS のグリッド列クラス
  def timeline_card_image_grid_class(image_count)
    image_count >= CARD_IMAGE_LIMIT ? "grid-cols-2" : "grid-cols-1"
  end
end
