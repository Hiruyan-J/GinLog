# さけのわAPIから取得するエリア(都道府県)マスターデータ
class Area < ApplicationRecord
  NAME_MAX_LENGTH = 10

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }

  # マスターデータのため削除不可。誤って destroy が呼ばれた場合に例外で知らせる
  has_many :breweries, dependent: :restrict_with_exception
end
