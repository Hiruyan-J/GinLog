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
FactoryBot.define do
  factory :label_extraction_log do
    association :user
    executed_on { Date.current }
  end
end
