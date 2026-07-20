# == Schema Information
#
# Table name: sakes
#
#  id           :bigint           not null, primary key
#  product_name :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  brand_id     :bigint           not null
#
# Indexes
#
#  index_sakes_on_brand_id                   (brand_id)
#  index_sakes_on_brand_id_and_product_name  (brand_id,product_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (brand_id => brands.id)
#
FactoryBot.define do
  factory :sake do
    sequence(:product_name) { |n| "テスト純米吟醸#{n}" }
    association :brand
  end
end
