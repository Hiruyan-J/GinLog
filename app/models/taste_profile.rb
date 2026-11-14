# == Schema Information
#
# Table name: taste_profiles
#
#  id                                                                   :bigint           not null, primary key
#  acidity_intensity(酸味の強弱(0〜10)。NULL = 記録なし)                :float
#  carbonation(炭酸感 0:無し 1:ガス感 2:微発泡 3:発泡。NULL = 記録なし) :integer
#  finish_intensity(余韻の長さ(0〜10)。NULL = 記録なし)                 :float
#  maturity_intensity(熟成度の強弱(0〜10)。NULL = 記録なし)             :float
#  sweetness_intensity(甘味の強弱(0〜10)。NULL = 記録なし)              :float
#  umami_intensity(旨味の強弱(0〜10)。NULL = 記録なし)                  :float
#  created_at                                                           :datetime         not null
#  updated_at                                                           :datetime         not null
#  sake_log_id                                                          :bigint           not null
#
# Indexes
#
#  index_taste_profiles_on_sake_log_id  (sake_log_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (sake_log_id => sake_logs.id)
#
# 日本酒記録の「味わいの詳細」
class TasteProfile < ApplicationRecord
  INTENSITY_MIN = 0
  INTENSITY_MAX = 10
  # 未記録のときのスライダーのつまみの位置（値としては保存しない）
  INTENSITY_DEFAULT = 5.0
  # 強弱の項目と、スライダー両端の表示 [弱い側, 強い側]
  INTENSITY_SCALES = {
    sweetness_intensity: [ "サッパリ", "フルーティー" ],
    umami_intensity: [ "スッキリ・淡麗", "コクがある・濃厚" ],
    acidity_intensity: [ "弱い", "強い" ],
    maturity_intensity: [ "フレッシュ・新鮮", "熟成" ],
    finish_intensity: [ "短い", "長い" ]
  }.freeze
  # 炭酸感の表示名（キーは enum のキー）
  CARBONATION_LABELS = {
    "still" => "無し",
    "gassy" => "ガス感",
    "slightly_sparkling" => "微発泡",
    "sparkling" => "発泡"
  }.freeze
  # 記録できる項目すべて（フォームとの受け渡しに使う）
  RECORD_ATTRIBUTES = [ *INTENSITY_SCALES.keys, :carbonation ].freeze

  belongs_to :sake_log

  # validate: { allow_nil: true } … 想定外の値は例外ではなくバリデーションエラーにする（nil = 記録なしは許可）
  enum :carbonation, { still: 0, gassy: 1, slightly_sparkling: 2, sparkling: 3 }, validate: { allow_nil: true }

  INTENSITY_SCALES.each_key do |attribute|
    validates attribute, numericality: { greater_than_or_equal_to: INTENSITY_MIN,
                                         less_than_or_equal_to: INTENSITY_MAX },
                         allow_nil: true
  end

  # 1項目でも記録されているか（0 も「記録あり」として扱う）
  # @return [Boolean] 記録された項目があれば true
  def recorded?
    RECORD_ATTRIBUTES.any? { |attribute| !public_send(attribute).nil? }
  end
end
