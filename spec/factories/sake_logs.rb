FactoryBot.define do
  factory :sake_log do
    rating { 4 }
    taste_strength { 4.0 }
    aroma_strength { 2.0 }
    review { "甘く肉料理にも負けない味" }
    association :user
    association :sake
  end
end
