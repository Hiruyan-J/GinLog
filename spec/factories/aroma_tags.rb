FactoryBot.define do
  factory :aroma_tag do
    category { :ginjo }
    sequence(:name) { |n| "香りタグ#{n}" }
    sequence(:position) { |n| n }
  end
end
