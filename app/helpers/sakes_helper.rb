# 日本酒の銘柄・商品名・蔵元・都道府県をリンクで表示するヘルパー
module SakesHelper
  # 文字リンクのクラス（カード全体のリンク z-10 より手前に出すため relative z-20 を付ける）
  # スマホでもリンクと分かるよう、薄い下線を常に表示する
  TEXT_LINK_CLASS = "relative z-20 link underline-offset-2 decoration-neutral-300 active:opacity-60".freeze

  # 銘柄名を、その銘柄で絞り込んだ検索結果へのリンクにする
  # @param brand [Brand] 銘柄
  # @return [ActiveSupport::SafeBuffer] a タグ
  def brand_link(brand)
    sake_search_link(brand.name, brand_id: brand.id)
  end

  # 商品名を、日本酒詳細へのリンクにする（右に「›」アイコンを付ける）
  # @param sake [Sake] 日本酒
  # @param truncate [Boolean] true なら長い商品名を 1 行に収めて「…」で省略する
  # @return [ActiveSupport::SafeBuffer] a タグ
  def product_name_link(sake, truncate: false)
    name = tag.span(sake.product_name, class: class_names("link underline-offset-2 decoration-neutral-300", truncate: truncate))
    icon = tag.span("chevron_right", class: "material-symbols-rounded ms-size-16 shrink-0 align-middle text-primary")
    link_to sake_path(sake),
            class: class_names("relative z-20 active:opacity-60", "inline-flex max-w-full items-center" => truncate),
            data: { turbo_frame: "_top" } do
      safe_join([ name, icon ])
    end
  end

  # 「蔵元名 / 都道府県名」を、それぞれで絞り込んだ検索結果へのリンクにして並べる
  # @param brewery [Brewery] 蔵元（area を読み込み済みのもの）
  # @return [ActiveSupport::SafeBuffer] 灰色の「/」でつないだ a タグ 2つ
  def brewery_and_area_links(brewery)
    separator = tag.span("/", class: "mx-1 text-neutral-400")
    safe_join([
      sake_search_link(brewery.name, brewery_id: brewery.id),
      sake_search_link(brewery.area.name, area_id: brewery.area_id)
    ], separator)
  end

  private

  # 絞り込み付きの検索結果へのリンク
  # @param text [String] リンクの文字
  # @param filter [Hash] 絞り込み条件（brand_id: / brewery_id: / area_id: のどれか）
  # @return [ActiveSupport::SafeBuffer] a タグ
  def sake_search_link(text, **filter)
    link_to text, sakes_path(**filter), class: TEXT_LINK_CLASS, data: { turbo_frame: "_top" }
  end
end
