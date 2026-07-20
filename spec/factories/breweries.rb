# == Schema Information
#
# Table name: breweries
#
#  id          :bigint           not null, primary key
#  is_deleted  :boolean          default(FALSE), not null
#  name        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  area_id     :bigint           not null
#  sakenowa_id :integer
#
# Indexes
#
#  index_breweries_on_area_id      (area_id)
#  index_breweries_on_sakenowa_id  (sakenowa_id) UNIQUE WHERE (sakenowa_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (area_id => areas.id)
#
FactoryBot.define do
  factory :brewery do
    sequence(:name) { |n| "テスト酒造#{n}" }
    association :area
  end
end
