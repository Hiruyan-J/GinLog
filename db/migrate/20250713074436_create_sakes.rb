class CreateSakes < ActiveRecord::Migration[7.2]
  def change
    create_table :sakes do |t|
      t.string :product_name, null: false
      t.timestamps
    end
  end
end
