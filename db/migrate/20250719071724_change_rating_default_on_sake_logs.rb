class ChangeRatingDefaultOnSakeLogs < ActiveRecord::Migration[7.2]
  def change
    change_column_default :sake_logs, :rating, from: nil, to: "0"
  end
end
