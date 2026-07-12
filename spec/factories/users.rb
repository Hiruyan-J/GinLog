FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:name) { |n| "テストユーザー#{n}" }
    password { "password" }
  end
end
