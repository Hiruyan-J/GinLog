class CreateLikes < ActiveRecord::Migration[8.1]
  def change
    create_table :likes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :sake_log, null: false, foreign_key: true

      t.timestamps

      t.index %i[user_id sake_log_id], unique: true
    end
  end
end
