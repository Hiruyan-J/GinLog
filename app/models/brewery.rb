# == Schema Information
#
# Table name: breweries
#
#  id          :bigint           not null, primary key
#  is_deleted  :boolean          default(FALSE), not null
#  name        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  area_id     :bigint           not null
#  sakenowa_id :integer
#
# Indexes
#
#  index_breweries_on_area_id      (area_id)
#  index_breweries_on_sakenowa_id  (sakenowa_id) UNIQUE WHERE (sakenowa_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (area_id => areas.id)
#
class Brewery < ApplicationRecord
  NAME_MAX_LENGTH = 255

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }
  validates :sakenowa_id, uniqueness: true, allow_nil: true

  scope :active, -> { where(is_deleted: false) }

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
  # マスターデータのため削除不可。誤って destroy が呼ばれた場合に例外で知らせる
  has_many :brands, dependent: :restrict_with_exception
end
