class CreateAromaTags < ActiveRecord::Migration[8.1]
  def change
    create_table :aroma_tags do |t|
      t.integer :category, null: false, comment: "香りの区分 0:吟醸香 1:原料香 2:熟成香"
      t.string :name, null: false, comment: "タグ名（例: リンゴ・洋梨）"
      t.integer :position, null: false, comment: "区分の中での表示順"

      t.timestamps
    end
    add_index :aroma_tags, [ :category, :name ], unique: true
    # 区分の中で表示順が重ならないようにする（チェックはトランザクションの最後）
    add_unique_constraint :aroma_tags, [ :category, :position ], deferrable: :deferred
  end
end
