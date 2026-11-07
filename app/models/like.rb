# == Schema Information
#
# Table name: likes
#
#  id          :bigint           not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  sake_log_id :bigint           not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_likes_on_sake_log_id              (sake_log_id)
#  index_likes_on_user_id                  (user_id)
#  index_likes_on_user_id_and_sake_log_id  (user_id,sake_log_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (sake_log_id => sake_logs.id)
#  fk_rails_...  (user_id => users.id)
#
# 日本酒記録へのいいね
class Like < ApplicationRecord
  belongs_to :user
  belongs_to :sake_log

  validates :user_id, uniqueness: { scope: :sake_log_id }
end
