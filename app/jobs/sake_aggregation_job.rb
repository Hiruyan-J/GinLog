# sake 1件の集計値（平均・件数）を再計算するジョブ。
# SakeLog の保存・削除のたびに after_commit から登録される（SakeLog#enqueue_sake_aggregation）
class SakeAggregationJob < ApplicationJob
  queue_as :default

  # 集計を実行し、投稿が0件になった sake は削除する（どの画面からも辿れなくなるため）
  # @param sake_id [Integer] 再集計する Sake の ID
  # @return [void]
  def perform(sake_id)
    sake = Sake.find_by(id: sake_id)
    # 同じ sake に対するジョブが複数積まれ、先に実行された方が sake を削除した場合に nil になる
    # （商品名を編集した直後の削除、sakes:aggregate_all の実行中にユーザーが記録を削除、など）
    # その場合は何もしない
    return if sake.nil?

    sake.refresh_aggregation!
    sake.destroy! if sake.sake_logs_count.zero?
  end
end
