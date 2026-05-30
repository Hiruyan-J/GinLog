# 名前・商品名などのテキスト属性を正規化する共通モジュール。
#
# 表記揺れ（全角スペース・全角英数字・半角カナ・各種ダッシュ等）を吸収し、
# find_or_create_by 等の重複判定で同一の値が確実に一致するようにする。
module Normalizable
  extend ActiveSupport::Concern

  # 半角ハイフンに統一する対象（長音「ー」U+30FC は意図的に含めない）
  # - U+2010〜U+2015: ハイフン・各種ダッシュ（HYPHEN 〜 HORIZONTAL BAR）
  # - U+2212: MINUS SIGN（マイナス記号）
  # - U+FE58: SMALL EM DASH / U+FE63: SMALL HYPHEN-MINUS
  HYPHEN_LIKE = /[‐-―−﹘﹣]/

  # テキストを正規化する。
  #
  # 処理順:
  # 1. NFKC 正規化（全角英数字→半角、半角カナ→全角、全角スペース→半角、互換文字の展開）
  # 2. 長音以外のハイフン・ダッシュ・マイナス類を半角ハイフン "-" に統一
  # 3. 連続する空白を半角スペース1つに圧縮
  # 4. 前後の空白を除去
  #
  # @param value [String, nil] 正規化対象の文字列
  # @return [String, nil] 正規化後の文字列（nil はそのまま返す）
  def self.normalize_text(value)
    return value if value.nil?

    value.unicode_normalize(:nfkc)
          .gsub(HYPHEN_LIKE, "-")
          .gsub(/[[:space:]]+/, " ")
          .strip
  end

  class_methods do
    # 指定した属性にテキスト正規化 (normalize_text) を適用する
    # normalizes は保存時だけでなく、 find_or_create_by 等の検索時にも適用されるため、
    # 既存の重複判定ロジック (SakeLogForm) とそのまま整合する。
    #
    # @param attribute_names [Array<Symbol>] 正規化対象の属性名
    # @return [void]
    def normalizes_text(*attribute_names)
      attribute_names.each do |attribute_name|
        normalizes attribute_name, with: ->(value) { Normalizable.normalize_text(value) }
      end
    end
  end
end
