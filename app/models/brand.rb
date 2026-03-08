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
#  sakenowa_id :integer          not null
#
# Indexes
#
#  index_brands_on_brewery_id   (brewery_id)
#  index_brands_on_sakenowa_id  (sakenowa_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (brewery_id => breweries.id)
#
# さけのわAPIから取得する銘柄マスターデータ
class Brand < ApplicationRecord
  NAME_MAX_LENGTH = 255

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }

  scope :active, -> { where(is_deleted: false) }

  belongs_to :brewery
end
