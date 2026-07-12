FactoryBot.define do
  factory :brewery do
    sequence(:name) { |n| "テスト酒造#{n}" }
    association :area
  end
end
