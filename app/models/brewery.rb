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
#  sakenowa_id :integer          not null
#
# Indexes
#
#  index_breweries_on_area_id      (area_id)
#  index_breweries_on_sakenowa_id  (sakenowa_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (area_id => areas.id)
#
# さけのわAPIから取得する蔵元マスターデータ
class Brewery < ApplicationRecord
  NAME_MAX_LENGTH = 255

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }

  scope :active, -> { where(is_deleted: false) }

  belongs_to :area
  # マスターデータのため削除不可。誤って destroy が呼ばれた場合に例外で知らせる
  has_many :brands, dependent: :restrict_with_exception
end
