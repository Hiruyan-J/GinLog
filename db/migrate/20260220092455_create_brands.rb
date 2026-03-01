class CreateBrands < ActiveRecord::Migration[7.2]
  def change
    create_table :brands do |t|
      t.integer :sakenowa_id, null: false
      t.string :name, null: false
      t.references :brewery, null: false, foreign_key: true
      t.boolean :is_deleted, null: false, default: false

      t.timestamps
    end

    add_index :brands, :sakenowa_id, unique: true
  end
end
