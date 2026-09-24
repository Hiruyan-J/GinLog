class CreateLabelExtractionLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :label_extraction_logs, comment: "AIラベル読み取りの実行履歴。1日あたりの回数制限に使用" do |t|
      # index: false にしているのは、下の複合インデックスが user_id 単独の検索も
      # まかなえるため（左端のカラムだけでも使える）。単独インデックスは重複になる
      t.references :user, null: false, foreign_key: true, index: false
      t.date :executed_on, null: false, comment: "実行日（日本時間）。1日あたりの回数制限の集計キー"

      t.timestamps

      t.index [ :user_id, :executed_on ]
    end
  end
end
