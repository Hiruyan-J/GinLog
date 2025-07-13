class Sake < ApplicationRecord
  validates :product_name, presence: true, length: { maximum: 255 }

  has_many :sake_logs, dependent: :destroy
end
