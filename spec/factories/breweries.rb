# == Schema Information
#
# Table name: breweries
#
#  id             :bigint           not null, primary key
#  is_deleted     :boolean          default(FALSE), not null
#  name           :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  area_id        :bigint           not null
#  merged_into_id :bigint
#  sakenowa_id    :integer
#
# Indexes
#
#  index_breweries_on_area_id         (area_id)
#  index_breweries_on_merged_into_id  (merged_into_id)
#  index_breweries_on_sakenowa_id     (sakenowa_id) UNIQUE WHERE (sakenowa_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (area_id => areas.id)
#  fk_rails_...  (merged_into_id => breweries.id)
#
FactoryBot.define do
  factory :brewery do
    sequence(:name) { |n| "テスト酒造#{n}" }
    association :area
  end
end
