class RemoveDefaultRatingOnSakeLogs < ActiveRecord::Migration[7.2]
  def change
    change_column_default :sake_logs, :rating, from: 0, to: nil
  end
end
