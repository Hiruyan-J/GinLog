# == Schema Information
#
# Table name: sake_logs
#
#  id             :bigint           not null, primary key
#  aroma_strength :float            not null
#  rating         :integer          default(0), not null
#  review         :text
#  taste_strength :float            not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  sake_id        :bigint           not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_sake_logs_on_sake_id  (sake_id)
#  index_sake_logs_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (sake_id => sakes.id)
#  fk_rails_...  (user_id => users.id)
#
class SakeLog < ApplicationRecord
  validates :rating, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: RATING_MIN = 0, less_than_or_equal_to: RATING_MAX = 5 }
  validates :taste_strength, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }
  validates :aroma_strength, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }
  validates :review, length: { maximum: 65_535 }

  belongs_to :user
  belongs_to :sake

  accepts_nested_attributes_for :sake
end
