# == Schema Information
#
# Table name: aroma_profiles
#
#  id                                                         :bigint           not null, primary key
#  aged_aroma_intensity(熟成香の強弱(0〜10)。NULL = 記録なし) :float
#  ginjo_intensity(吟醸香の強弱(0〜10)。NULL = 記録なし)      :float
#  ingredient_intensity(原料香の強弱(0〜10)。NULL = 記録なし) :float
#  created_at                                                 :datetime         not null
#  updated_at                                                 :datetime         not null
#  sake_log_id                                                :bigint           not null
#
# Indexes
#
#  index_aroma_profiles_on_sake_log_id  (sake_log_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (sake_log_id => sake_logs.id)
#

# 日本酒記録の「香りの詳細」
class AromaProfile < ApplicationRecord
  INTENSITY_MIN = 0
  INTENSITY_MAX = 10
  # 未記録のときのスライダーのつまみの位置（値としては保存しない）
  INTENSITY_DEFAULT = 5.0
  # 強弱 0 の意味（スライダーの左端・記録詳細に表示する）。0 のときはタグを選べない
  NONE_LABEL = "無し".freeze
  # 香りの区分（AromaTag の category）ごとの強弱の列
  INTENSITY_ATTRIBUTES = {
    "ginjo" => :ginjo_intensity,
    "ingredient" => :ingredient_intensity,
    "aged" => :aged_aroma_intensity
  }.freeze
  # 香りの区分ごとの説明（項目名の下に表示する）
  DESCRIPTIONS = {
    "ginjo" => "リンゴやメロン、バナナのような果物や、花の香り",
    "ingredient" => "炊いた米や餅、栗のような香りや、ヨーグルトのような香り",
    "aged" => "蜂蜜やドライフルーツ、醤油のような、熟成で生まれる香り"
  }.freeze
  # 香りの評価の基準（「香りの濃淡」と「香り」の見出しの横に表示する）
  EVALUATION_NOTE = "嗅いだ香りと口に含んだ香りの両方の印象".freeze

  belongs_to :sake_log
  has_many :aroma_profile_aroma_tags, dependent: :destroy
  has_many :aroma_tags, through: :aroma_profile_aroma_tags

  INTENSITY_ATTRIBUTES.each_value do |attribute|
    validates attribute, numericality: { greater_than_or_equal_to: INTENSITY_MIN,
                                         less_than_or_equal_to: INTENSITY_MAX },
                         allow_nil: true
  end

  # 1項目でも記録されているか（強弱の 0 も、タグ1つだけでも「記録あり」）
  # @return [Boolean] 記録された項目があれば true
  def recorded?
    INTENSITY_ATTRIBUTES.each_value.any? { |attribute| !public_send(attribute).nil? } || aroma_tags.any?
  end

  # 指定した区分の、選んだタグを表示順で返す（読み込み済みのタグから絞り込むので SQL は増えない）
  # @param category [String] AromaTag の category（"ginjo" など）
  # @return [Array<AromaTag>] 選んだタグ。無ければ空の配列
  def aroma_tags_for(category)
    aroma_tags.select { |aroma_tag| aroma_tag.category == category }.sort_by(&:position)
  end
end
