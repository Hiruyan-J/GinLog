FactoryBot.define do
  factory :aroma_profile do
    association :sake_log
    ginjo_intensity { 5.0 }
    ingredient_intensity { 5.0 }
    aged_aroma_intensity { 5.0 }

    trait :blank do
      ginjo_intensity { nil }
      ingredient_intensity { nil }
      aged_aroma_intensity { nil }
    end
  end
end
