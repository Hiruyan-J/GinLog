# == Schema Information
#
# Table name: comments
#
#  id          :bigint           not null, primary key
#  body        :text             not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  sake_log_id :bigint           not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_comments_on_sake_log_id  (sake_log_id)
#  index_comments_on_user_id      (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (sake_log_id => sake_logs.id)
#  fk_rails_...  (user_id => users.id)
#
# 日本酒記録へのコメント
class Comment < ApplicationRecord
  BODY_MAX_LENGTH = 500

  belongs_to :user
  belongs_to :sake_log

  normalizes :body, with: ->(value) { value.strip }

  validates :body, presence: true, length: { maximum: BODY_MAX_LENGTH }

  # 投稿後に本文を編集したか
  # 投稿時は created_at と updated_at が同じ時刻になり、編集すると updated_at だけが進む
  # @return [Boolean] 編集済みなら true
  def edited?
    updated_at > created_at
  end
end
