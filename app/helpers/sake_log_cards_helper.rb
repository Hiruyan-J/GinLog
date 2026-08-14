# 記録カード（timelines/_sake_log・sake_logs/_sake_log）の画像表示ロジックをまとめたヘルパー
#
# SakeLog の画像スロットは最大4枚だが、カードでは先頭2枚だけを並べ、
# 3枚目以降は枚数バッジ（+N）で知らせる。
# 全部見たい場合はカードをタップして記録詳細画面へ遷移してもらう。
module SakeLogCardsHelper
  # 記録カードに並べるラベル画像の最大枚数
  #
  # 下の CARD_GRID_CLASS / CARD_SINGLE_IMAGE_CLASS と対になっている。
  #   枚数を変えるときは、この3つを必ずセットで書き換えること。
  #
  # 【なぜクラス名を組み立てないのか】
  # Tailwind はソースコードを文字列として走査し、見つけたクラス名だけを CSS に出力する。
  # "grid-cols-#{CARD_IMAGE_LIMIT}" のように組み立てると `grid-cols-` までしか読めず、
  # grid-cols-2 の CSS が生成されずスタイルが当たらない。
  # そのため、定数には完成したクラス名を文字列でそのまま持たせている。
  # （config/tailwind.config.js の content に app/helpers/**/*.rb が入っているので、
  #   ヘルパー内に書いた文字列であれば検出される）
  CARD_IMAGE_LIMIT = 2

  # 画像グリッドの列数クラス（CARD_IMAGE_LIMIT 列）
  CARD_GRID_CLASS = "grid-cols-2".freeze

  # 1マスしか無いときに、全マス分の場所の中央へ置くためのクラス
  #   col-span-2 … CARD_IMAGE_LIMIT マス分の場所を取る
  #   w-1/2      … その中で 1/CARD_IMAGE_LIMIT の幅にする（＝2枚のときの1マスと同じ大きさ）
  #   mx-auto    … 左右の余白を均等にして中央へ
  CARD_SINGLE_IMAGE_CLASS = "col-span-2 mx-auto w-1/2".freeze

  # カードに並べる画像（先頭 CARD_IMAGE_LIMIT 枚）を返す
  #
  # @param attached_images [Array<Array(Symbol, ActiveStorage::Attached::One)>] SakeLog#attached_images の戻り値
  # @return [Array<Array(Symbol, ActiveStorage::Attached::One)>] カードに表示する分だけに絞った配列
  def sake_log_card_images(attached_images)
    attached_images.first(CARD_IMAGE_LIMIT)
  end

  # カードに表示しきれなかった画像の枚数を返す
  #
  # @param attached_images [Array<Array(Symbol, ActiveStorage::Attached::One)>] SakeLog#attached_images の戻り値
  # @return [Integer] 表示しきれなかった枚数（すべて表示できていれば 0）
  def sake_log_hidden_image_count(attached_images)
    [ attached_images.size - CARD_IMAGE_LIMIT, 0 ].max
  end

  # 画像グリッド（親要素）の列数クラスを返す
  #
  # 枚数によらず常に CARD_IMAGE_LIMIT 列にする。
  # 1マスしか無いときの見え方は sake_log_card_image_class 側で調整する。
  #
  # @return [String] Tailwind CSS のグリッド列クラス
  def sake_log_card_grid_class
    CARD_GRID_CLASS
  end

  # カード内の画像1マスに付けるクラスを返す
  #
  # 2マス埋まるときは何も付けない（グリッドがそのまま2列に並べる）。
  # 1マスしか無いときは col-span-2 で2マス分の場所を取り、
  # その中で w-1/2 + mx-auto にして「2枚のときと同じ大きさ・中央寄せ」にする。
  #
  # ※ マスの間隔（gap-1 = 4px）の分だけ2枚のときより約2px 広くなるが、見た目には分からない差。
  #
  # @param image_count [Integer] カードに表示する画像の枚数（プレースホルダーのみのときは 0）
  # @return [String] Tailwind CSS のクラス（2マス埋まるときは空文字）
  def sake_log_card_image_class(image_count)
    image_count >= CARD_IMAGE_LIMIT ? "" : CARD_SINGLE_IMAGE_CLASS
  end
end
