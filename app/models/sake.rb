# == Schema Information
#
# Table name: sakes
#
#  id           :bigint           not null, primary key
#  brand_name   :string
#  product_name :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  brand_id     :bigint
#
# Indexes
#
#  index_sakes_on_brand_id  (brand_id)
#
# Foreign Keys
#
#  fk_rails_...  (brand_id => brands.id)
#
class Sake < ApplicationRecord
  PRODUCT_NAME_MAX_LENGTH = 255

  validates :product_name, presence: true, length: { maximum: PRODUCT_NAME_MAX_LENGTH }

  has_many :sake_logs
end
