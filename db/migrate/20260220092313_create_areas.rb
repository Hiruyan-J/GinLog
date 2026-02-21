class CreateAreas < ActiveRecord::Migration[7.2]
  def change
    create_table :areas do |t|
      t.integer :sakenowa_id, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :areas, :sakenowa_id, unique: true
  end
end
