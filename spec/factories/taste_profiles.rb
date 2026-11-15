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
FactoryBot.define do
  factory :taste_profile do
    association :sake_log
    sweetness_intensity { 5.0 }
    umami_intensity { 5.0 }
    acidity_intensity { 5.0 }
    maturity_intensity { 5.0 }
    finish_intensity { 5.0 }
    carbonation { :still }

    trait :blank do
      sweetness_intensity { nil }
      umami_intensity { nil }
      acidity_intensity { nil }
      maturity_intensity { nil }
      finish_intensity { nil }
      carbonation { nil }
    end
  end
end
