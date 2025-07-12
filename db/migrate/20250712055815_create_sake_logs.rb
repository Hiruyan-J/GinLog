class CreateSakeLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :sake_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :rating, null: false, limit: 1
      t.float :taste_strength, null: false
      t.float :aroma_strength, null: false
      t.timestamps
    end
  end
end
