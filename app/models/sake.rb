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
  validates :product_name, presence: true, length: { maximum: 255 }

  has_many :sake_logs
end
