class CreateAromaProfileAromaTags < ActiveRecord::Migration[8.1]
  def change
    create_table :aroma_profile_aroma_tags do |t|
      t.references :aroma_profile, null: false, foreign_key: true, index: false
      t.references :aroma_tag, null: false, foreign_key: true

      t.timestamps
    end
    add_index :aroma_profile_aroma_tags, [ :aroma_profile_id, :aroma_tag_id ], unique: true
  end
end
