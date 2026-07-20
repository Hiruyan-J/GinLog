# == Schema Information
#
# Table name: sake_logs
#
#  id             :bigint           not null, primary key
#  aroma_strength :float            not null
#  rating         :integer          not null
#  review         :text
#  taste_strength :float            not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  sake_id        :bigint           not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_sake_logs_on_sake_id  (sake_id)
#  index_sake_logs_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (sake_id => sakes.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :sake_log do
    rating { 3 }
    taste_strength { 5.0 }
    aroma_strength { 5.0 }
    review { "華やかな香りで美味しい" }
    association :user
    association :sake
  end
end
