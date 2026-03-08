class AddBrandIdToSakes < ActiveRecord::Migration[7.2]
  def change
    add_reference :sakes, :brand, null: true, foreign_key: true
  end
end
