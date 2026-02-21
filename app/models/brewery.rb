# さけのわAPIから取得する蔵元マスターデータ
class Brewery < ApplicationRecord
  NAME_MAX_LENGTH = 255

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }

  belongs_to :area
  # マスターデータのため削除不可。誤って destroy が呼ばれた場合に例外で知らせる
  has_many :brands, dependent: :restrict_with_exception
end
