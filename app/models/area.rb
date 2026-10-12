# == Schema Information
#
# Table name: areas
#
#  id          :bigint           not null, primary key
#  name        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  sakenowa_id :integer          not null
#
# Indexes
#
#  index_areas_on_sakenowa_id  (sakenowa_id) UNIQUE
#
# さけのわAPIから取得するエリア(都道府県)マスターデータ
class Area < ApplicationRecord
  NAME_MAX_LENGTH = 10

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }

  # マスターデータのため削除不可。誤って destroy が呼ばれた場合に例外で知らせる
  has_many :breweries, dependent: :restrict_with_exception

  # Ransack で検索を許可するカラム
  # @param _auth_object [Object, nil] 権限の出し分け用（未使用）
  # @return [Array<String>]
  def self.ransackable_attributes(_auth_object = nil)
    %w[name]
  end

  # Ransack で検索を許可する関連（都道府県から先はたどらせない）
  # @param _auth_object [Object, nil] 権限の出し分け用（未使用）
  # @return [Array<String>]
  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
