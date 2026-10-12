# == Schema Information
#
# Table name: sakes
#
#  id                                                              :bigint           not null, primary key
#  average_aroma_strength(香りの濃淡の平均。未集計・投稿0件は nil) :float
#  average_rating(好み度の平均。未集計・投稿0件は nil)             :float
#  average_taste_strength(味の濃淡の平均。未集計・投稿0件は nil)   :float
#  product_name                                                    :string           not null
#  sake_logs_count(投稿件数。未集計でも0でよいため not null)       :integer          default(0), not null
#  created_at                                                      :datetime         not null
#  updated_at                                                      :datetime         not null
#  brand_id                                                        :bigint           not null
#
# Indexes
#
#  index_sakes_on_brand_id                   (brand_id)
#  index_sakes_on_brand_id_and_product_name  (brand_id,product_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (brand_id => brands.id)
#
class Sake < ApplicationRecord
  include Normalizable

  PRODUCT_NAME_MAX_LENGTH = 255
  # フリーワード検索で使う単語数の上限（超えた分は無視する）
  KEYWORD_MAX_WORDS = 5

  normalizes_text :product_name

  validates :product_name, presence: true, length: { maximum: PRODUCT_NAME_MAX_LENGTH }
  validates :product_name, uniqueness: { scope: :brand_id }

  belongs_to :brand

  has_many :sake_logs

  # 商品名オートコンプリート用のスコープ
  # @param brand_id [Integer] 銘柄ID
  # @param query [String] 検索文字列
  # @return [ActiveRecord::Relation<Sake>]
  scope :search_by_product_name, ->(brand_id, query) {
    next none if query.blank?

    where(brand_id: brand_id)
      .where("product_name LIKE ?", "%#{sanitize_sql_like(query)}%")
  }

  # フリーワード検索の対象（商品名・銘柄名・蔵元名・都道府県名）をまとめた別名
  ransack_alias :keyword, :product_name_or_brand_name_or_brand_brewery_name_or_brand_brewery_area_name

  # フリーワード検索用のスコープ（空白区切りは AND 検索）
  # 銘柄名が検索語と完全一致する日本酒を先頭に並べる
  # @param keyword [String, nil] 検索文字列
  # @return [ActiveRecord::Relation<Sake>] キーワードが空なら 0 件
  scope :search_by_keyword, ->(keyword) {
    normalized_keyword = Normalizable.normalize_text(keyword.to_s)
    words = normalized_keyword.split(" ").first(KEYWORD_MAX_WORDS)
    next none if words.empty?

    # 単語ごとに条件のグループ（g）を作り、グループ同士を AND（m）でつなぐ
    ransack(m: "and", g: words.map { |word| { keyword_cont: word } }).result
      .order(brand_name_match_order([ normalized_keyword, *words ]))
  }

  # 銘柄名が候補のどれかと完全一致する行を先にする並び順（大文字小文字は区別しない）
  # brands テーブルが JOIN 済みの検索で使うこと（search_by_keyword では Ransack が JOIN する）
  # @param candidates [Array<String>] 銘柄名と比べる文字列（検索文字列の全体と、各単語）
  # @return [Arel::Nodes::Case] 完全一致なら 0、それ以外は 1 になる CASE 式
  def self.brand_name_match_order(candidates)
    exact_match = Brand.arel_table[:name].lower.in(candidates.map(&:downcase).uniq)
    Arel::Nodes::Case.new.when(exact_match).then(0).else(1)
  end

  # Ransack で検索を許可するカラム
  # @param _auth_object [Object, nil] 権限の出し分け用（未使用）
  # @return [Array<String>]
  def self.ransackable_attributes(_auth_object = nil)
    %w[product_name]
  end

  # Ransack で検索を許可する関連
  # @param _auth_object [Object, nil] 権限の出し分け用（未使用）
  # @return [Array<String>]
  def self.ransackable_associations(_auth_object = nil)
    %w[brand]
  end

  # 商品名の照合キー（空白をすべて取り除いた形）
  #
  # normalizes_text は連続する空白を1つに縮めるだけで、空白そのものは残す。
  # そのため「純米中取り無調整生」と「純米中取り 無調整生」は別の値として扱われ、
  # 同じ商品なのに2レコードに割れてしまう。
  # 保存する値は入力どおりのままにしたいので、照合するときだけ空白を取り除く。
  #
  # @param product_name [String, nil] 商品名
  # @return [String] 空白を除いた商品名（nil は空文字になる）
  def self.spaceless_key(product_name)
    Normalizable.normalize_text(product_name).to_s.delete(" ")
  end

  # 銘柄と商品名から既存レコードを探し、無ければ新規に組み立てる
  #
  # 空白の有無だけが違う商品名は同じ商品とみなす。
  # 一方で「恵乃智」と「純米吟醸 恵乃智」のような部分一致では寄せない。
  # 「久保田 千寿」と「久保田 千寿 秋あがり」のように、部分一致でも
  # 別商品であるケースが実在し、文字列だけでは区別できないため。
  # 部分一致の救済は、画面で候補を見せてユーザーに選ばせる側で行う。
  #
  # @param brand_id [Integer] 銘柄ID
  # @param product_name [String] 商品名
  # @return [Sake] 既存または新規の Sake
  def self.find_or_initialize_by_product_name(brand_id, product_name)
    find_by(brand_id: brand_id, product_name: product_name) ||
      find_by_spaceless_product_name(brand_id, product_name) ||
      new(brand_id: brand_id, product_name: product_name)
  end

  # 空白の有無だけが違う商品名で既存レコードを探す
  #
  # DBの product_name は normalizes_text 済み（全角スペースは半角に変換済み）なので、
  # 比較対象は半角スペースだけを取り除けばよい。
  # brand_id で絞ってから比較するため、走査対象は1銘柄ぶんの数件で済む。
  #
  # @param brand_id [Integer] 銘柄ID
  # @param product_name [String] 商品名
  # @return [Sake, nil] 見つかった既存レコード（無ければ nil）
  def self.find_by_spaceless_product_name(brand_id, product_name)
    key = spaceless_key(product_name)
    return nil if key.blank?

    where(brand_id: brand_id).find_by("replace(product_name, ' ', '') = ?", key)
  end

  # sake_logs の平均値と件数を再計算して保存する
  # SakeAggregationJobとrakeタスク(sakes:aggregate_all)から呼ばれる
  #
  # sake_logs_count は Rails の counter_cache 機能では更新していない。
  # counter_cache と同じ命名だが、平均値と同じタイミング・同じ集計処理でまとめて
  # 更新したいため、ここで一緒に計算している。
  # （そのため SakeLog の belongs_to :sake に counter_cache: true は付けない）
  #
  # @return [void]
  def refresh_aggregation!
    update!(
      sake_logs_count: sake_logs.count,
      average_rating: rounded_average(:rating),
      average_taste_strength: rounded_average(:taste_strength),
      average_aroma_strength: rounded_average(:aroma_strength)
    )
  end

  # 集計値が算出済みかどうか
  # （投稿直後はジョブ実行前のため nil のことがある。集計時は平均3つが同時に入るので代表して1つを見る）
  def aggregated?
    average_rating.present?
  end

  private

  # sake_logs の指定カラムの平均を小数第2位で丸めて返す
  # @param column [Symbol] 平均を取るカラム名（:rating など）
  # @return [Float, nil] 平均値（投稿が0件なら nil）
  def rounded_average(column)
    sake_logs.average(column)&.round(2)&.to_f
  end
end
