# == Schema Information
#
# Table name: sakes
#
#  id                                                              :bigint           not null, primary key
#  average_aroma_strength(香りの濃淡の平均。未集計・投稿0件は nil) :float
#  average_rating(好み度の平均。未集計・投稿0件は nil)             :float
#  average_taste_strength(味の濃淡の平均。未集計・投稿0件は nil)   :float
#  product_name                                                    :string           not null
#  sake_logs_count(投稿件数。未集計でも0でよいため not null)       :integer          default(0), not null
#  created_at                                                      :datetime         not null
#  updated_at                                                      :datetime         not null
#  brand_id                                                        :bigint           not null
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
