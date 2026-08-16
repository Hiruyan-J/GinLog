class AddConfirmableToUsers < ActiveRecord::Migration[8.1]
  # change ではなく up / down に分ける
  #   理由: 既存ユーザーの更新（execute）は「元に戻す方法」を Rails が自動判断できないため。
  def up
    # 確認メールのリンクに埋め込むトークン
    add_column :users, :confirmation_token, :string
    # 確認が完了した日付(nil = 未確認)
    add_column :users, :confirmed_at, :datetime
    # 確認メールを送った日時
    add_column :users, :confirmation_sent_at, :datetime
    # メールアドレス変更時、確認が済むまで新アドレスを一時的に置いておく列
    add_column :users, :unconfirmed_email, :string

    add_index :users, :confirmation_token, unique: true

    # この対応より前に登録した人は「確認済み」として扱う。
    # 将来モデルの実装が変わってもマイグレーションが壊れないようにするため、
    # モデル（User.update_all）ではなく SQL で実装
    execute "UPDATE users SET confirmed_at = CURRENT_TIMESTAMP WHERE confirmed_at IS NULL"
  end

  def down
    # カラムを削除すると、そのカラムに付いているインデックスも一緒に消える
    remove_column :users, :confirmation_token
    remove_column :users, :confirmed_at
    remove_column :users, :confirmation_sent_at
    remove_column :users, :unconfirmed_email
  end
end
