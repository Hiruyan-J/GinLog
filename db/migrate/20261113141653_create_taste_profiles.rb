class CreateTasteProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :taste_profiles do |t|
      t.references :sake_log, null: false, foreign_key: true, index: { unique: true }
      t.float :sweetness_intensity, comment: "甘味の強弱(0〜10)。NULL = 記録なし"
      t.float :umami_intensity, comment: "旨味の強弱(0〜10)。NULL = 記録なし"
      t.float :acidity_intensity, comment: "酸味の強弱(0〜10)。NULL = 記録なし"
      t.float :maturity_intensity, comment: "熟成度の強弱(0〜10)。NULL = 記録なし"
      t.float :finish_intensity, comment: "余韻の長さ(0〜10)。NULL = 記録なし"
      t.integer :carbonation, comment: "炭酸感 0:無し 1:ガス感 2:微発泡 3:発泡。NULL = 記録なし"

      t.timestamps
    end
  end
end
