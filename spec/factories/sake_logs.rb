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
