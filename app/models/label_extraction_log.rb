# AIラベル読み取りの実行履歴（1行 = 1回の実行）
# Gemini API の呼び出しコストを守るため、1ユーザーあたり1日の実行回数を制限する
# == Schema Information
#
# Table name: label_extraction_logs(AIラベル読み取りの実行履歴。1日あたりの回数制限に使用)
#
#  id                                                             :bigint           not null, primary key
#  executed_on(実行日（日本時間）。1日あたりの回数制限の集計キー) :date             not null
#  created_at                                                     :datetime         not null
#  updated_at                                                     :datetime         not null
#  user_id                                                        :bigint           not null
#
# Indexes
#
#  index_label_extraction_logs_on_user_id_and_executed_on  (user_id,executed_on)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class LabelExtractionLog < ApplicationRecord
  # 1ユーザーが1日に実行できる上限回数
  DAILY_LIMIT = 20

  belongs_to :user

  # 実行日は常に「日本時間の今日」。呼び出し側が指定し忘れても埋まるようにする
  before_validation :set_executed_on, on: :create

  validates :executed_on, presence: true

  # 今日（日本時間）の実行分に絞るスコープ
  scope :today, -> { where(executed_on: Date.current) }

  # 本日の上限に達しているか
  # @param user [User] 判定対象のユーザー
  # @return [Boolean] 上限に達していれば true
  def self.limit_reached?(user)
    remaining_for(user) <= 0
  end

  # 本日の残り実行可能回数
  # @param user [User] 対象のユーザー
  # @return [Integer] 残り回数(0未満にはならない)
  def self.remaining_for(user)
    [ DAILY_LIMIT - today.where(user: user).count, 0 ].max
  end

  private

  # 実行日をセットする
  # Date.current は Time.zone(config.time_zone = "Tokyo")を見るため日本時間の今日になる。
  # Date.today はサーバーのOSタイムゾーンを見てしまうので使わないこと
  # @return [void]
  def set_executed_on
    self.executed_on ||= Date.current
  end
end
