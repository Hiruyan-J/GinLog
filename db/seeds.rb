# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# 香りの種類タグ（区分ごとに表示順で並べる。）
aroma_tag_names = {
  "ginjo" => [ "リンゴ・洋梨", "バナナ・メロン", "柑橘", "花", "その他の吟醸香" ],
  "ingredient" => [ "炊いた米・米麹", "餅・和菓子", "栗・木の実", "ヨーグルト・乳製品", "その他の原料香" ],
  "aged" => [ "蜂蜜・カラメル", "ドライフルーツ", "ナッツ（ローストしたような）", "醤油・味噌", "スパイス", "木・樽", "その他の熟成香" ]
}

# 表示順の重複チェックはトランザクションの最後に行われる（途中で番号が重なってもよい）
AromaTag.transaction do
  aroma_tag_names.each do |category, names|
    names.each.with_index(1) do |name, position|
      aroma_tag = AromaTag.find_or_initialize_by(category: category, name: name)
      aroma_tag.update!(position: position)
    end
  end
end
