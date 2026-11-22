# == Schema Information
#
# Table name: aroma_profile_aroma_tags
#
#  id               :bigint           not null, primary key
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  aroma_profile_id :bigint           not null
#  aroma_tag_id     :bigint           not null
#
# Indexes
#
#  idx_on_aroma_profile_id_aroma_tag_id_75194f4c18  (aroma_profile_id,aroma_tag_id) UNIQUE
#  index_aroma_profile_aroma_tags_on_aroma_tag_id   (aroma_tag_id)
#
# Foreign Keys
#
#  fk_rails_...  (aroma_profile_id => aroma_profiles.id)
#  fk_rails_...  (aroma_tag_id => aroma_tags.id)
#

# 香りの詳細と香りの種類タグをつなぐ中間テーブル
class AromaProfileAromaTag < ApplicationRecord
  belongs_to :aroma_profile
  belongs_to :aroma_tag
end
