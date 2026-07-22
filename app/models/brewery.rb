# == Schema Information
#
# Table name: breweries
#
#  id             :bigint           not null, primary key
#  is_deleted     :boolean          default(FALSE), not null
#  name           :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  area_id        :bigint           not null
#  merged_into_id :bigint
#  sakenowa_id    :integer
#
# Indexes
#
#  index_breweries_on_area_id         (area_id)
#  index_breweries_on_merged_into_id  (merged_into_id)
#  index_breweries_on_sakenowa_id     (sakenowa_id) UNIQUE WHERE (sakenowa_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (area_id => areas.id)
#  fk_rails_...  (merged_into_id => breweries.id)
#
class Brewery < ApplicationRecord
  include Normalizable

  NAME_MAX_LENGTH = 255

  normalizes_text :name

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }
  validates :sakenowa_id, uniqueness: true, allow_nil: true

  scope :active, -> { where(is_deleted: false) }

  # import_brands の統合先解決マップ作成で使用
  scope :merged, -> { where.not(merged_into_id: nil) }

  # オートコンプリート用の蔵元検索スコープ
  # 都道府県を eager load し、蔵元名で部分位置検索(上位10件)
  # @param query [String] 検索文字列
  # @return [ActiveRecord::Relation<Brewery>]
  scope :search_by_name, ->(query) {
    next none if query.blank?

    active
      .includes(:area)
      .where("breweries.name LIKE ?", "%#{sanitize_sql_like(query)}%")
      .limit(10)
  }

  belongs_to :area
  # 統合先の蔵元（自分が重複データだった場合のみ設定される）
  belongs_to :merged_into, class_name: "Brewery", optional: true

  # 自分を統合先としている重複蔵元の一覧
  has_many :merged_from, class_name: "Brewery", foreign_key: :merged_into_id,
                         inverse_of: :merged_into, dependent: :restrict_with_exception
  # マスターデータのため削除不可。誤って destroy が呼ばれた場合に例外で知らせる
  has_many :brands, dependent: :restrict_with_exception
end
