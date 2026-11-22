class CreateAromaProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :aroma_profiles do |t|
      t.references :sake_log, null: false, foreign_key: true, index: { unique: true }
      t.float :ginjo_intensity, comment: "吟醸香の強弱(0〜10)。NULL = 記録なし"
      t.float :ingredient_intensity, comment: "原料香の強弱(0〜10)。NULL = 記録なし"
      t.float :aged_aroma_intensity, comment: "熟成香の強弱(0〜10)。NULL = 記録なし"

      t.timestamps
    end
  end
end
