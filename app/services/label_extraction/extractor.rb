module LabelExtraction
  # ラベル画像の読み取りとマスタ照合をまとめて行うサービス
  #
  # 戻り値の形:
  #   {
  #     extraction:     { brand_name:, product_name:, product_name_alternatives:, ... },
  #     brand_match:    { status: "single" | "multiple" | "none", candidates: [...] },
  #     brewery_match:  { status: "single" | "multiple" | "none", candidates: [...] },
  #     brewery_brands: [ 銘柄候補, ... ]（蔵元だけ確定した場合。それ以外は空配列）
  #     brand_sakes:    [ 商品名候補, ... ]（銘柄が確定した場合。それ以外は空配列）
  #     area:           { id:, name: } または nil
  #   }
  class Extractor
    PROMPT_PATH = Rails.root.join("app/prompts/label_extraction.md")

    # 各画像の直前に置く説明文。
    #
    # 画像の並び順ではなく、この文言で表・裏を伝えるため、
    # 片方だけを渡しても役割が正しく伝わる。
    #
    # app/prompts/label_extraction.md の
    # 「各画像の直前に、それが表ラベルか裏ラベルかを示す文を置きます」
    # と対になる文章なので、使用するプロンプトを指定する本クラスで全文を組み立てる。
    IMAGE_CAPTIONS = {
      front: "次の画像は表ラベルです。",
      back: "次の画像は裏ラベルです。"
    }.freeze

    # 商品名の別候補は多すぎると選びにくいため上限を設ける
    # 変更するときは app/prompts/label_extraction.md の件数の記載も合わせること
    # （プロンプトは素のテキストのまま扱いたいので、あえて定数を埋め込んでいない）
    ALTERNATIVES_MAX = 3

    # 銘柄候補の表示上限（既存のオートコンプリート Brand.search_by_name と揃える）
    # 「どぶろく」のような一般名詞に近い銘柄名は同名が増えやすいため上限を設ける
    CANDIDATES_MAX = 10

    # 蔵元名の先頭・末尾に付く法人格（マスタ照合の前に取り除く）
    LEGAL_ENTITY_PATTERN = /\A(株式会社|有限会社|合資会社|合名会社|合同会社)|(株式会社|有限会社|合資会社|合名会社|合同会社)\z/

    # Gemini の構造化出力に強制するスキーマ
    # これにより「JSONのパースに失敗する」「項目が欠ける」事故を防ぐ
    RESPONSE_SCHEMA = {
      type: "OBJECT",
      properties: {
        brand_name: { type: "STRING", nullable: true, description: "銘柄" },
        product_name: { type: "STRING", nullable: true, description: "商品名の第1候補" },
        product_name_alternatives: { type: "ARRAY", items: { type: "STRING" }, maxItems: ALTERNATIVES_MAX,
                                     description: "商品名の別候補（最大#{ALTERNATIVES_MAX}件）" },
        brewery_name: { type: "STRING", nullable: true, description: "蔵元名（法人格を除いた形）" },
        brewery_name_raw: { type: "STRING", nullable: true, description: "ラベル記載の蔵元名（原文）" },
        prefecture: { type: "STRING", nullable: true, description: "蔵元の所在地の都道府県" },
        confidence: { type: "STRING", enum: %w[high medium low], description: "読み取り全体の確信度" }
      },
      required: %w[brand_name product_name product_name_alternatives brewery_name brewery_name_raw prefecture confidence]
    }.freeze

    # @param front_image [Hash, nil] 表ラベル画像 { mime_type: String, data: String(バイナリ) }
    # @param back_image [Hash, nil] 裏ラベル画像（形式は front_image と同じ）
    # @raise [ArgumentError] 表・裏のどちらも指定されなかった場合
    def initialize(front_image: nil, back_image: nil)
      if front_image.nil? && back_image.nil?
        raise ArgumentError, "表ラベルと裏ラベルのどちらか1枚以上を指定してください"
      end

      @front_image = front_image
      @back_image = back_image
    end

    # 読み取りとマスタ照合を実行する
    # @return [Hash] 抽出結果と照合結果（クラスコメント参照）
    # @raise [GeminiClient::ApiError] すべてのモデルで失敗した場合
    def call
      extraction = normalize_extraction(
        GeminiClient.generate_with_fallback(
          prompt: File.read(PROMPT_PATH),
          images: captioned_images,
          response_schema: RESPONSE_SCHEMA
        )
      )

      brand_match = match_brands(extraction[:brand_name], extraction[:brewery_name], extraction[:prefecture])
      brewery_match = match_breweries(extraction[:brewery_name], extraction[:brewery_name_raw], extraction[:prefecture])

      {
        extraction: extraction,
        brand_match: brand_match,
        brewery_match: brewery_match,
        brewery_brands: brands_of_matched_brewery(brand_match, brewery_match),
        brand_sakes: sakes_of_matched_brand(brand_match, extraction[:product_name]),
        area: match_area(extraction[:prefecture])
      }
    end

    private

    # 送信する画像に、直前へ置く説明文を付けて並べる
    #
    # @return [Array<Hash>] { caption:, mime_type:, data: } の配列（指定された画像のみ）
    def captioned_images
      { front: @front_image, back: @back_image }.filter_map do |slot, image|
        image.merge(caption: IMAGE_CAPTIONS[slot]) if image
      end
    end

    # 抽出結果の各文字列をマスタと同じルール（Normalizable）で正規化する
    # 全角スペース等の表記揺れで照合に失敗するのを防ぐ
    # @param extraction [Hash] Gemini の抽出結果
    # @return [Hash] 正規化済みの抽出結果
    def normalize_extraction(extraction)
      {
        brand_name: normalize(extraction[:brand_name]),
        product_name: normalize(extraction[:product_name]),
        # 件数は maxItems でも縛っているが、スキーマ違反が絶対に起きない保証はないため
        # ここでも切り詰める（表示側で件数が想定を超えないことを保証する）
        product_name_alternatives: Array(extraction[:product_name_alternatives])
                                    .filter_map { |name| normalize(name) }
                                    .first(ALTERNATIVES_MAX),
        brewery_name: normalize(extraction[:brewery_name]),
        brewery_name_raw: normalize(extraction[:brewery_name_raw]),
        prefecture: normalize(extraction[:prefecture]),
        confidence: extraction[:confidence]
      }
    end

    # @param value [String, nil]
    # @return [String, nil] 正規化後の文字列（空文字は nil に落とす）
    def normalize(value)
      Normalizable.normalize_text(value).presence
    end

    # 銘柄名をマスタと照合する
    # 完全一致を優先し、なければ部分一致（既存のオートコンプリートと同じ検索）へ落とす
    # 「どぶろく」のように同名の銘柄が複数ある場合は、AIが読んだ蔵元名・都道府県で並べ替える
    # @param brand_name [String, nil] 抽出された銘柄名
    # @param brewery_name [String, nil] 抽出された蔵元名（並べ替えのヒントに使う）
    # @param prefecture [String, nil] 抽出された都道府県（並べ替えのヒントに使う）
    # @return [Hash] { status:, candidates: }
    def match_brands(brand_name, brewery_name, prefecture)
      return { status: "none", candidates: [] } if brand_name.blank?

      brands = Brand.active.includes(brewery: :area).where(name: brand_name).to_a
      brands = Brand.search_by_name(brand_name).to_a if brands.empty?
      brands = sort_by_likeness(brands, brewery_name, prefecture) { |brand| brand.brewery }

      build_match(brands.first(CANDIDATES_MAX).map { |brand| brand_candidate(brand) })
    end

    # 蔵元は1件に確定したのに、銘柄がマスタで見つからなかった場合に、
    # その蔵元の銘柄一覧を返す
    #
    # 例: 飛鸞の裏ラベルには、ものによっては「HIRAN」としか書かれておらず、AIがそう読むのは正しい。
    # しかしマスタの銘柄名は「飛鸞」なので検索が0件になり、
    # そのまま登録すると森酒造場に「飛鸞」「HIRAN」という重複した銘柄ができてしまう。
    # 蔵元（森酒造場）は確定しているので、その銘柄から選べれば重複を防げる。
    #
    # @param brand_match [Hash] 銘柄の照合結果
    # @param brewery_match [Hash] 蔵元の照合結果
    # @return [Array<Hash>] 銘柄候補の配列（該当しない場合は空配列）
    def brands_of_matched_brewery(brand_match, brewery_match)
      return [] unless brand_match[:status] == "none" && brewery_match[:status] == "single"

      Brand.active.includes(brewery: :area)
           .where(brewery_id: brewery_match[:candidates].first[:id])
           .order(:name)
           .first(CANDIDATES_MAX)
           .map { |brand| brand_candidate(brand) }
    end

    # 銘柄が1件に確定したとき、その銘柄に登録済みの商品名を返す
    #
    # AIが読んだ商品名をそのまま登録すると、既存の商品名と
    # 「恵乃智」「純米吟醸 恵乃智」のようにレコードが割れることがある。
    # 割れると日本酒詳細のページと集計が2つに分かれてしまう。
    #
    # 空白の有無だけの違い（「純米中取り無調整生」と「純米中取り 無調整生」）は
    # 保存時に Sake 側で吸収するが、それ以外はここで候補として見せてユーザーに選ばせる。
    # 「久保田 千寿」と「久保田 千寿 秋あがり」のように、
    # 部分一致でも別商品であるケースが実在し、機械では判断できないため。
    #
    # @param brand_match [Hash] 銘柄の照合結果
    # @param product_name [String, nil] AIが読んだ商品名（並べ替えのヒントに使う）
    # @return [Array<Hash>] 商品名候補の配列（該当しない場合は空配列）
    def sakes_of_matched_brand(brand_match, product_name)
      return [] unless brand_match[:status] == "single"

      sakes = Sake.where(brand_id: brand_match[:candidates].first[:id]).order(:product_name).to_a
      sort_by_product_name_likeness(sakes, product_name)
        .first(CANDIDATES_MAX)
        .map { |sake| sake_candidate(sake) }
    end

    # 登録済みの商品名を、AIが読んだ商品名に近い順へ並べ替える
    #
    # 銘柄によっては商品が20件以上あり、CANDIDATES_MAX で
    # 切ると肝心の1件が候補から漏れてしまうため、近いものを先頭に寄せる。
    #
    # @param sakes [Array<Sake>] 並べ替え対象
    # @param product_name [String, nil] AIが読んだ商品名
    # @return [Array<Sake>] 近い順（同点なら元の商品名順を保つ）
    def sort_by_product_name_likeness(sakes, product_name)
      return sakes if sakes.size <= 1 || product_name.blank?

      key = Sake.spaceless_key(product_name)
      # sort_by は同点の順序が保証されないため、元の並び順(index)を第2キーにする
      sakes.each_with_index
           .sort_by { |sake, index| [ -product_name_likeness(sake, key), index ] }
           .map(&:first)
    end

    # 登録済み商品名が、AIが読んだ商品名とどれだけ近いかを点数にする
    # ここでの一致は「並べ替えのヒント」であって、統合の判断には使わない
    # @param sake [Sake] 採点対象の商品
    # @param key [String] AIが読んだ商品名の照合キー（空白を除いた形）
    # @return [Integer] 大きいほど近い（0〜2）
    def product_name_likeness(sake, key)
      sake_key = Sake.spaceless_key(sake.product_name)
      return 2 if sake_key == key # 空白の有無だけが違う
      return 1 if sake_key.include?(key) || key.include?(sake_key) # 「恵乃智」と「純米吟醸恵乃智」

      0
    end

    # 候補を、AIが読んだ蔵元名・都道府県に近い順へ並べ替える
    #
    # 銘柄候補と蔵元候補の両方で使えるよう、採点対象の Brewery はブロックで取り出す。
    # 採点基準を1箇所にまとめることで、銘柄と蔵元で並び順の判定がズレるのを防ぐ。
    #
    # @param records [Array<Brand, Brewery>] 並べ替え対象
    # @param brewery_name [String, nil] 抽出された蔵元名
    # @param prefecture [String, nil] 抽出された都道府県
    # @yieldparam record [Brand, Brewery] 並べ替え対象の1件
    # @yieldreturn [Brewery] 採点に使う蔵元
    # @return [Array<Brand, Brewery>] 一致度の高い順（同点なら元の順序を保つ）
    def sort_by_likeness(records, brewery_name, prefecture)
      return records if records.size <= 1

      # sort_by は同点の順序が保証されないため、元の並び順(index)を第2キーにする
      records.each_with_index
             .sort_by { |record, index| [ -brewery_likeness(yield(record), brewery_name, prefecture), index ] }
             .map(&:first)
    end

    # 蔵元1件が、AIの読み取りとどれだけ一致しているかを点数にする
    # @param brewery [Brewery] 採点対象の蔵元
    # @param brewery_name [String, nil] 抽出された蔵元名
    # @param prefecture [String, nil] 抽出された都道府県
    # @return [Integer] 大きいほど一致度が高い（0〜5）
    def brewery_likeness(brewery, brewery_name, prefecture)
      score = prefecture.present? && brewery.area.name == prefecture ? 1 : 0
      return score if brewery_name.blank?

      if brewery.name == brewery_name
        score + 4 # 蔵元名が完全一致
      elsif brewery.name.include?(brewery_name) || brewery_name.include?(brewery.name)
        score + 2 # 「山本」と「山本酒造店」のような部分一致
      else
        score
      end
    end

    # 蔵元名をマスタと照合する（銘柄が特定できなかったときのフォールバック用）
    # ラベルの蔵元名は「株式会社山本酒造店」のように法人格つきで書かれるため、
    # 法人格を除いた形でも照合する
    # @param brewery_name [String, nil] 法人格を除いた蔵元名
    # @param brewery_name_raw [String, nil] ラベル原文の蔵元名
    # @param prefecture [String, nil] 抽出された都道府県（並べ替えのヒントに使う）
    # @return [Hash] { status:, candidates: }
    def match_breweries(brewery_name, brewery_name_raw, prefecture)
      query_names = [ brewery_name, strip_legal_entity(brewery_name_raw) ].compact_blank.uniq
      return { status: "none", candidates: [] } if query_names.empty?

      breweries = Brewery.active.includes(:area).where(name: query_names).to_a
      # 完全一致が無ければ、読み取れた名前すべてで部分一致を試す。
      # AIが brewery_name 側だけ短縮・誤読していても、原文側の名前で拾えるようにする
      # （完全一致は最初から query_names 全件を対象にしているので、そちらに合わせる）
      breweries = query_names.flat_map { |name| partial_match_breweries(name) }.uniq if breweries.empty?
      breweries = sort_by_likeness(breweries, brewery_name, prefecture) { |brewery| brewery }

      build_match(breweries.first(CANDIDATES_MAX).map { |brewery| brewery_candidate(brewery) })
    end

    # 蔵元名の部分一致検索（双方向）
    # 「山本酒造店」→ マスタ「山本」のように、抽出名がマスタ名を含むケースも拾う
    # @param name [String] 検索する蔵元名
    # @return [Array<Brewery>]
    def partial_match_breweries(name)
      contains = Brewery.search_by_name(name).to_a
      contained = Brewery.active.includes(:area)
                         .where("? LIKE '%' || breweries.name || '%'", name)
                         .limit(10).to_a
      (contains + contained).uniq
    end

    # 銘柄候補1件をフロントへ返すJSONの形にする
    # （/api/brands/search のレスポンスと同じ形に揃える）
    # @param brand [Brand]
    # @return [Hash]
    def brand_candidate(brand)
      {
        id: brand.id,
        name: brand.name,
        brewery_id: brand.brewery.id,
        brewery_name: brand.brewery.name,
        area_id: brand.brewery.area.id,
        area_name: brand.brewery.area.name,
        label: "#{brand.name} - #{brand.brewery.name} (#{brand.brewery.area.name})"
      }
    end

    # 蔵元候補1件をフロントへ返すJSONの形にする
    # @param brewery [Brewery]
    # @return [Hash]
    def brewery_candidate(brewery)
      {
        id: brewery.id,
        name: brewery.name,
        area_id: brewery.area.id,
        area_name: brewery.area.name,
        label: "#{brewery.name}（#{brewery.area.name}）"
      }
    end

    # 商品名候補1件をフロントへ返すJSONの形にする
    # sake_id を持たせることで、選んだときに既存レコードへ確実に紐づけられる
    # @param sake [Sake]
    # @return [Hash]
    def sake_candidate(sake)
      {
        sake_id: sake.id,
        product_name: sake.product_name,
        label: "#{sake.product_name}（吟ログに記録あり）"
      }
    end

    # 候補の件数から照合ステータスを決める
    # @param candidates [Array<Hash>]
    # @return [Hash] { status: "none" | "single" | "multiple", candidates: }
    def build_match(candidates)
      status =
        case candidates.size
        when 0 then "none"
        when 1 then "single"
        else "multiple"
        end
      { status: status, candidates: candidates }
    end

    # 都道府県名を areas マスタと照合する
    # @param prefecture [String, nil]
    # @return [Hash, nil] { id:, name: } または nil
    def match_area(prefecture)
      return nil if prefecture.blank?

      area = Area.find_by(name: prefecture)
      area && { id: area.id, name: area.name }
    end

    # 蔵元名から法人格（株式会社など）を取り除く
    # @param name [String, nil]
    # @return [String, nil]
    def strip_legal_entity(name)
      return nil if name.blank?

      name.gsub(LEGAL_ENTITY_PATTERN, "").strip
    end
  end
end
