class AddAggregationColumnsToSakes < ActiveRecord::Migration[8.1]
  def change
    add_column :sakes, :average_rating, :float, comment: "好み度の平均。未集計・投稿0件は nil"
    add_column :sakes, :average_taste_strength, :float, comment: "味の濃淡の平均。未集計・投稿0件は nil"
    add_column :sakes, :average_aroma_strength, :float, comment: "香りの濃淡の平均。未集計・投稿0件は nil"

    add_column :sakes, :sake_logs_count, :integer, null: false, default: 0, comment: "投稿件数。未集計でも0でよいため not null"
  end
end
