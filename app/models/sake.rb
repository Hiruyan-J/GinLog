# == Schema Information
#
# Table name: sakes
#
#  id           :bigint           not null, primary key
#  brand_name   :string
#  product_name :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  brand_id     :bigint
#
# Indexes
#
#  index_sakes_on_brand_id  (brand_id)
#
# Foreign Keys
#
#  fk_rails_...  (brand_id => brands.id)
#
class Sake < ApplicationRecord
  PRODUCT_NAME_MAX_LENGTH = 255

  validates :product_name, presence: true, length: { maximum: PRODUCT_NAME_MAX_LENGTH }

  belongs_to :brand, optional: true

  has_many :sake_logs

  # 商品名オートコンプリート用のスコープ
  # @param brand_id [Integer] 銘柄ID
  # @param query [String] 検索文字列
  # @return [ActiveRecord::Relation<Sake>]
  scope :search_by_product_name, ->(brand_id, query){
    where(brand_id: brand_id)
      .where("product_name LIKE ?", "%#{sanitize_sql_like(query)}%")
      .limit(10)
  }
end
