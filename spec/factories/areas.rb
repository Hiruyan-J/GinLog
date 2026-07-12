FactoryBot.define do
  factory :area do
    sequence(:name) { |n| "都道府県#{n}" }
    sequence(:sakenowa_id) { |n| n }
  end
end
