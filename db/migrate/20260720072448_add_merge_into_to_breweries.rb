class AddMergeIntoToBreweries < ActiveRecord::Migration[8.0]
  def change
    add_reference :breweries, :merged_into, foreign_key: { to_table: :breweries }
  end
end
