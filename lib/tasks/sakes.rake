# sakes テーブルの集計用 Rake タスク
namespace :sakes do
  desc "全 sake の集計値（平均・件数）を再計算する。集計ロジック変更時に手動実行する"
  task aggregate_all: :environment do
    puts "全 #{Sake.count} 件の sake を再集計します..."

    # ジョブと同じ処理を1件ずつ同期実行する (投稿0件の sake はジョブ側の判定で削除される)
    Sake.find_each do |sake|
      SakeAggregationJob.perform_now(sake.id)
    end

    puts "再集計完了 (sake: #{Sake.count} 件)"
  rescue => e
    puts e.full_message
    exit 1
  end
end
