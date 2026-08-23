# sake 1件の集計値（平均・件数）を再計算するジョブ。
# SakeLog の保存・削除のたびに after_commit から登録される（SakeLog#enqueue_sake_aggregation）
class SakeAggregationJob < ApplicationJob
  queue_as :default

  # 集計を実行し、投稿が0件になった sake は削除する（どの画面からも辿れなくなるため）
  # @param sake_id [Integer] 再集計する Sake の ID
  # @return [void]
  def perform(sake_id)
    sake = Sake.find_by(id: sake_id)
    # ジョブ実行前に sake ごと削除されていることがある（記録の連続削除など）。その場合は何もしない
    return if sake.nil?

    sake.refresh_aggregation!
    sake.destroy! if sake.sake_logs_count.zero?
  end
end
