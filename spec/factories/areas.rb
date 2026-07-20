# == Schema Information
#
# Table name: areas
#
#  id          :bigint           not null, primary key
#  name        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  sakenowa_id :integer          not null
#
# Indexes
#
#  index_areas_on_sakenowa_id  (sakenowa_id) UNIQUE
#
FactoryBot.define do
  factory :area do
    sequence(:name) { |n| "都道府県#{n}" }
    sequence(:sakenowa_id) { |n| n }
  end
end
