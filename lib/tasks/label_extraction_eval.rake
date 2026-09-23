# ============================================
# 使い方:
#   EVAL_DIR=/path/to/images docker compose exec web bin/rails label_extraction:eval
#   （EVAL_DIR には画像と eval_expected.csv を置く。CSVの列:
#     front_image, back_image, brand_name, product_name, brewery_name, prefecture
#     正解が複数ある場合は「飛鸞/HIRAN」のように / 区切りで書ける）
#
# モデルを切り替えて比較する場合:
#   GEMINI_MODEL=gemini-3.5-flash-lite EVAL_DIR=... bin/rails label_extraction:eval
# ============================================

# 評価タスク用のヘルパー
module LabelExtractionEval
  module_function

  # 画像ファイルを Extractor へ渡す Hash に変換する
  # @param path [String] 画像ファイルのパス
  # @return [Hash] { mime_type:, data: }
  def read_image(path)
    mime_type = path.end_with?(".png") ? "image/png" : "image/jpeg"
    { mime_type: mime_type, data: File.binread(path) }
  end

  # 期待値と実際の値を比較する（期待値は「/」区切りで複数指定できる）
  #
  # 比較の前に期待値（CSV側）を正規化する理由
  # 突き合わせる相手（actuals）は、Geminiの回答を Extractor が正規化した値か、
  # マスタから引いた値（Brand/Brewery が normalizes_text で正規化）のどちらかで、
  # いずれも正規化済み。CSVの期待値だけが生の文字列なので、ここで同じルールに揃える。
  # そうしないと、全角英数字や全角スペースが混ざったときに、
  # 内容が合っていても不一致と判定されてしまう。
  #
  # presence で空を落としているのは、「AKABU/」のように区切りだけが
  # 残ってしまったときに、空文字で一致してしまうのを防ぐため。
  #
  # @param expected [String, nil] 正解（例: "飛鸞/HIRAN"）
  # @param actuals [Array<String, nil>] 実際の値の候補
  # @return [Boolean]
  def match?(expected, actuals)
    return false if expected.blank?

    expected_values = expected.split("/")
                              .filter_map { |value| Normalizable.normalize_text(value).presence }

    expected_values.intersect?(actuals.compact)
  end

  # 1件分の読み取り結果を採点する
  # @param row [CSV::Row] 正解データ
  # @param result [Hash] Extractor#call の戻り値
  # @return [Hash] 項目ごとの判定（"○" / "△" / "×"）
  def judge(row, result)
    extraction = result[:extraction]
    brand_single = result[:brand_match][:status] == "single" ? result[:brand_match][:candidates].first[:name] : nil
    brewery_single = result[:brewery_match][:status] == "single" ? result[:brewery_match][:candidates].first[:name] : nil

    product =
      if match?(row["product_name"], [ extraction[:product_name] ])
        "○"
      elsif match?(row["product_name"], extraction[:product_name_alternatives])
        "△" # 第1候補では外したが、別候補に正解が含まれる
      else
        "×"
      end

    {
      brand: match?(row["brand_name"], [ extraction[:brand_name], brand_single ]) ? "○" : "×",
      product: product,
      brewery: match?(row["brewery_name"], [ extraction[:brewery_name], extraction[:brewery_name_raw], brewery_single ]) ? "○" : "×",
      prefecture: match?(row["prefecture"], [ extraction[:prefecture] ]) ? "○" : "×"
    }
  end
end

namespace :label_extraction do
  desc "ラベル画像でAI読み取りの精度を検証する（EVAL_DIR に画像と eval_expected.csv を置く）"
  task eval: :environment do
    require "csv"

    eval_dir = ENV["EVAL_DIR"]
    abort("使い方: EVAL_DIR=/path/to/images bin/rails label_extraction:eval") if eval_dir.blank?

    csv_path = File.join(eval_dir, "eval_expected.csv")
    abort("#{csv_path} が見つかりません") unless File.exist?(csv_path)

    # 本命 → 退避 の順に、実際に試されるモデルを表示する
    puts "モデル: #{LabelExtraction::GeminiClient.models.join(" → ")}"
    puts "判定: ○=一致 / △=別候補に正解あり(商品名のみ) / ×=不一致"
    puts

    totals = Hash.new(0)
    elapsed_times = []

    CSV.foreach(csv_path, headers: true) do |row|
      front_image = LabelExtractionEval.read_image(File.join(eval_dir, row["front_image"]))
      back_image = row["back_image"].present? ? LabelExtractionEval.read_image(File.join(eval_dir, row["back_image"])) : nil

      begin
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = LabelExtraction::Extractor.new(front_image: front_image, back_image: back_image).call
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      rescue LabelExtraction::GeminiClient::ApiError => e
        puts "エラー #{row['front_image']}: #{e.message}"
        totals[:error] += 1
        next
      end

      elapsed_times << elapsed
      scores = LabelExtractionEval.judge(row, result)
      scores.each { |field, mark| totals[field] += 1 if mark != "×" }
      totals[:count] += 1

      extraction = result[:extraction]
      puts "銘柄#{scores[:brand]} 商品名#{scores[:product]} 蔵元#{scores[:brewery]} 都道府県#{scores[:prefecture]} " \
           "#{format('%5.1fs', elapsed)}  #{row['front_image']}"
      # 不一致の項目は実際の読み取り値を表示して原因を追えるようにする
      puts "    銘柄: #{extraction[:brand_name].inspect}（正解: #{row['brand_name']}）" if scores[:brand] == "×"
      puts "    商品名: #{extraction[:product_name].inspect} / 別候補: #{extraction[:product_name_alternatives].inspect}（正解: #{row['product_name']}）" if scores[:product] == "×"
      puts "    蔵元: #{extraction[:brewery_name].inspect}（正解: #{row['brewery_name']}）" if scores[:brewery] == "×"
      puts "    都道府県: #{extraction[:prefecture].inspect}（正解: #{row['prefecture']}）" if scores[:prefecture] == "×"
    end

    count = totals[:count]
    abort("評価できた件数が0件でした") if count.zero?

    puts
    puts "=== 結果（#{count}件、エラー#{totals[:error]}件）==="
    %i[brand product brewery prefecture].each do |field|
      label = { brand: "銘柄", product: "商品名", brewery: "蔵元", prefecture: "都道府県" }[field]
      puts "#{label.ljust(4, '　')}: #{totals[field]}/#{count}（#{(totals[field] * 100.0 / count).round}%）"
    end
    puts "平均時間: #{(elapsed_times.sum / elapsed_times.size).round(1)}s"
  end
end
