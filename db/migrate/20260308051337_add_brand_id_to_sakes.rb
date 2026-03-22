class AddBrandIdToSakes < ActiveRecord::Migration[7.2]
  def change
    add_reference :sakes, :brand, null: true, foreign_key: true
    add_index :sakes, [:brand_id, :product_name], unique: true
  end
end
