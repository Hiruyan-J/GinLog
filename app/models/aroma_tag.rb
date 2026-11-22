# == Schema Information
#
# Table name: aroma_tags
#
#  id                                              :bigint           not null, primary key
#  category(香りの区分 0:吟醸香 1:原料香 2:熟成香) :integer          not null
#  name(タグ名（例: リンゴ・洋梨）)                :string           not null
#  position(区分の中での表示順)                    :integer          not null
#  created_at                                      :datetime         not null
#  updated_at                                      :datetime         not null
#
# Indexes
#
#  index_aroma_tags_on_category_and_name  (category,name) UNIQUE
#

# 香りの種類タグ（例: 吟醸香の「リンゴ・洋梨」）
class AromaTag < ApplicationRecord
  enum :category, { ginjo: 0, ingredient: 1, aged: 2 }

  has_many :aroma_profile_aroma_tags, dependent: :restrict_with_error
  has_many :aroma_profiles, through: :aroma_profile_aroma_tags

  validates :name, presence: true, uniqueness: { scope: :category }
  validates :position, presence: true

  # 区分ごと・表示順に並べる
  scope :ordered, -> { order(:category, :position) }
end
