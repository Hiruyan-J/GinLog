# == Schema Information
#
# Table name: brands
#
#  id          :bigint           not null, primary key
#  is_deleted  :boolean          default(FALSE), not null
#  name        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  brewery_id  :bigint           not null
#  sakenowa_id :integer
#
# Indexes
#
#  index_brands_on_brewery_id   (brewery_id)
#  index_brands_on_sakenowa_id  (sakenowa_id) UNIQUE WHERE (sakenowa_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (brewery_id => breweries.id)
#
FactoryBot.define do
  factory :brand do
    sequence(:name) { |n| "テスト銘柄#{n}" }
    is_deleted { false }
    association :brewery
  end
end
