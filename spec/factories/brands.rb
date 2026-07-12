FactoryBot.define do
  factory :brand do
    sequence(:name) { |n| "テスト銘柄#{n}" }
    is_deleted { false }
    association :brewery
  end
end
