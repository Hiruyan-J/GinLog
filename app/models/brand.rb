# == Schema Information
#
# Table name: brands
#
#  id          :bigint           not null, primary key
#  is_deleted  :boolean          default(FALSE), not null
#  name        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  brewery_id  :bigint           not null
#  sakenowa_id :integer
#
# Indexes
#
#  index_brands_on_brewery_id   (brewery_id)
#  index_brands_on_sakenowa_id  (sakenowa_id) UNIQUE WHERE (sakenowa_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (brewery_id => breweries.id)
#
class Brand < ApplicationRecord
  include Normalizable

  NAME_MAX_LENGTH = 255

  normalizes_text :name

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }
  validates :sakenowa_id, uniqueness: true, allow_nil: true

  scope :active, -> { where(is_deleted: false) }

  # オートコンプリート用の銘柄検索スコープ
  # 蔵元・都道府県を eager load し、銘柄名で部分一致検索(上位10件)
  # @param query [String] 検索文字列
  # @return [ActiveRecord::Relation<Brand>]
  scope :search_by_name, ->(query) {
    next none if query.blank?

    active
      .includes(brewery: :area)
      .where("brands.name LIKE ?", "%#{sanitize_sql_like(query)}%")
      .limit(10)
  }

  belongs_to :brewery
  has_many :sakes

  # Ransack で検索を許可するカラム
  # @param _auth_object [Object, nil] 権限の出し分け用（未使用）
  # @return [Array<String>]
  def self.ransackable_attributes(_auth_object = nil)
    %w[name]
  end

  # Ransack で検索を許可する関連
  # @param _auth_object [Object, nil] 権限の出し分け用（未使用）
  # @return [Array<String>]
  def self.ransackable_associations(_auth_object = nil)
    %w[brewery]
  end
end
