# == Schema Information
#
# Table name: sakes
#
#  id           :bigint           not null, primary key
#  product_name :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class Sake < ApplicationRecord
  PRODUCT_NAME_MAX_LENGTH = 255

  validates :product_name, presence: true, length: { maximum: PRODUCT_NAME_MAX_LENGTH }

  has_many :sake_logs
end
