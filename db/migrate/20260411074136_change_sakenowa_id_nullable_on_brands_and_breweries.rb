class ChangeSakenowaIdNullableOnBrandsAndBreweries < ActiveRecord::Migration[7.2]
  def change
    change_column_null :brands, :sakenowa_id, true

    change_column_null :breweries, :sakenowa_id, true

    remove_index :brands, :sakenowa_id
    add_index :brands, :sakenowa_id, unique: true, where: "sakenowa_id IS NOT NULL", name: "index_brands_on_sakenowa_id"

    remove_index :breweries, :sakenowa_id
    add_index :breweries, :sakenowa_id, unique: true, where: "sakenowa_id IS NOT NULL", name: "index_breweries_on_sakenowa_id"
  end
end
