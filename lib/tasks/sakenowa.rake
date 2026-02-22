# さけのわAPIインポート用 Rakeタスク
namespace :sakenowa do
  desc "さけのわAPIからエリア・蔵元・銘柄データをインポート"
  task import: :environment do
    puts "さけのわAPIからデータをインポートします..."

    client = SakenowaApiClient.new
    client.import_all

    puts "インポート完了"
    puts "  エリア: #{Area.count} 件"
    puts "  蔵元  : #{Brewery.count} 件(削除済み: #{Brewery.where(:is_deleted true).count} 件)"
    puts "  銘柄  : #{Brand.count} 件(削除済み: #{Brand.where(:is_deleted true).count} 件)"
  rescue => e
    puts e.full_message
    exit 1
  end
end