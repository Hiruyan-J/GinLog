class ChangeBrandIdNotNullOnSakes < ActiveRecord::Migration[7.2]
  def up
    # 既存データの確認: brand_id が NULL の Sake レコードがあればエラーを発生
    null_count = Sake.where(brand_id: nil).count
    if null_count > 0
      raise "brand_id が NULL の Sake レコードが #{null_count} 件あります。先にデータ移行をしてください。"
    end

    change_column_null :sakes, :brand_id, false
  end

  def down
    change_column_null :sakes, :brand_id, true
  end
end
