# さけのわAPIから取得する銘柄マスターデータ
class Brand < ApplicationRecord
  NAME_MAX_LENGTH = 255

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }

  belongs_to :brewery
end
