FactoryBot.define do
  factory :sake do
    sequence(:product_name) { |n| "テスト純米吟醸#{n}" }
    association :brand
  end
end
