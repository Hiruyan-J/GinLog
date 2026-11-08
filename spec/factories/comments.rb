FactoryBot.define do
  factory :comment do
    association :user
    association :sake_log
    sequence(:body) { |n| "コメント#{n}" }
  end
end
