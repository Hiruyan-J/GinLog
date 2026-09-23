require "net/http"

module LabelExtraction
  # Gemini API の generateContent を呼び出す HTTP クライアント
  #
  # インスタンスは「指定された1つのモデルを叩く」ことだけを担当する。
  #
  # AI を使う機能からは generate_with_fallback を呼ぶ。
  # そうすれば、機能ごとにモデルの切り替え手順を書かなくて済む。
  #
  # @see https://ai.google.dev/gemini-api/docs
  class GeminiClient
    # API呼び出しの失敗（通信エラー・ブロック・不正レスポンス）を表す例外
    class ApiError < StandardError; end

    BASE_URL = "https://generativelanguage.googleapis.com"

    # 使用するモデル。本命が失敗したら退避モデルを試す
    #
    # 退避先は本命と世代を離すこと。
    # 特定モデルが高負荷で落ちると、利用者が隣の世代へ退避して連鎖的に落ちる
    # （実際に gemini-3.7-flash の障害中、gemini-3.6-flash も 503 になった）。
    #
    # どちらも環境変数で上書きできる（GEMINI_MODEL / GEMINI_FALLBACK_MODEL）
    PRIMARY_MODEL = "gemini-3.5-flash-lite"
    FALLBACK_MODEL = "gemini-3.1-flash-lite"

    # 接続確立を待つ時間（秒）
    OPEN_TIMEOUT = 5
    # 1回のリクエストでレスポンスを待つ時間（秒）
    READ_TIMEOUT = 30
    # リトライを含めた、このクライアント1つあたりの制限時間（秒）。
    #
    # READ_TIMEOUT と同じ値なので、無応答のときは1回で打ち切られる。
    # 応答しないモデルに同じ内容を投げ直しても結果は変わらないため、
    # 残り時間は同じモデルへのリトライではなく、次のモデルへの切り替えに使う
    # 一方 4xx/5xx は数秒で返るので、この30秒の中で3回まで再送できる。
    TOTAL_TIMEOUT = 30
    # 残り時間がこれ未満ならリトライしない（間に合わないため）
    MIN_ATTEMPT_SECONDS = 5
    # リトライ回数と、各リトライ前の待ち時間（秒）
    MAX_RETRIES = 2
    RETRY_WAIT_SECONDS = [ 1, 2 ].freeze
    # リトライ対象のHTTPステータス（レート制限・サーバー側の一時エラー）
    RETRYABLE_STATUSES = [ 429, 500, 502, 503 ].freeze

    # リトライ対象として扱う通信エラー
    #
    # いずれも「今は繋がらない」だけで、少し待てば回復する可能性がある。
    # タイムアウト（Net::OpenTimeout / Net::ReadTimeout）は待ち時間の扱いが
    # 違うため、ここには含めず別の rescue 節で捕まえる。
    CONNECTION_ERRORS = [
      SocketError,          # DNS解決に失敗した
      SystemCallError,      # 接続拒否・接続リセットなど（Errno::*）
      IOError,              # 応答の途中で切断された（EOFError など）
      OpenSSL::SSL::SSLError, # TLSのハンドシェイクに失敗した
      Net::HTTPBadResponse  # HTTPとして解釈できない応答が返った
    ].freeze

    # 直近のAPI呼び出しのトークン使用量
    # （自分でクライアントを作って generate を呼んだ場合に参照できる）
    # @return [Hash, nil] 例: { "promptTokenCount" => 2375, "candidatesTokenCount" => 71 }
    attr_reader :last_usage

    # 使用中のモデル名
    # @return [String]
    attr_reader :model

    # 試すモデルを本命→退避の順に並べる
    #
    # 環境変数が空文字のときも既定値へ落とす。
    # compose.yml の `GEMINI_MODEL: ${GEMINI_MODEL:-}` は、未設定でも
    # 「空文字がセットされた状態」でコンテナに渡るため、
    # ENV.fetch（キーの有無しか見ない）だと空のモデル名を採用してしまう。
    #
    # 本命と退避が同じ場合は1つにまとめる（同じモデルへ無駄に投げ直さない）。
    #
    # @return [Array<String>] 試す順に並んだモデル名
    def self.models
      [
        ENV["GEMINI_MODEL"].presence || PRIMARY_MODEL,
        ENV["GEMINI_FALLBACK_MODEL"].presence || FALLBACK_MODEL
      ].uniq
    end

    # モデルを順に試し、最初に成功した結果を返す
    #
    # AI を使う機能はこのメソッドを呼ぶ（切り替えの手順を機能ごとに書かないため）。
    # ユーザーから見れば1回の実行なので、利用回数の記録は呼び出し側で1回のまま。
    # 各モデルの制限時間は TOTAL_TIMEOUT なので、最悪でも
    # TOTAL_TIMEOUT × モデル数 で打ち切られる。
    #
    # @param prompt [String] プロンプト本文
    # @param images [Array<Hash>] 画像の配列（:caption, :mime_type, :data）
    # @param response_schema [Hash] 構造化出力のスキーマ
    # @return [Hash] 抽出結果（シンボルキー）
    # @raise [ApiError] すべてのモデルで失敗した場合
    def self.generate_with_fallback(prompt:, images:, response_schema:)
      failures = []

      models.each_with_index do |model, index|
        return new(model: model).generate(
          prompt: prompt,
          images: images,
          response_schema: response_schema
        )
      rescue ApiError => e
        failures << "#{model}: #{e.message}"
        raise ApiError, failures.join(" / ") if index == models.size - 1

        Rails.logger.warn("#{model} での読み取りに失敗しました（#{e.message}）。次のモデルを試します")
      end
    end

    # @param model [String] 使用するモデル名
    def initialize(model:)
      @model = model
    end

    # 画像つきプロンプトを送り、構造化出力のJSONをHashで受け取る
    # @param prompt [String] プロンプト本文
    # @param images [Array<Hash>] 画像の配列。
    #   要素は { caption: String, mime_type: String, data: String(バイナリ) }。
    #   caption は画像の直前に置く説明文（任意）。文言は呼び出し側が決める
    # @param response_schema [Hash] 構造化出力のスキーマ（Gemini の responseSchema 形式）
    # @return [Hash] 抽出結果（シンボルキー）
    # @raise [ApiError] 通信失敗・安全性ブロック・レスポンス不正の場合
    def generate(prompt:, images:, response_schema:)
      response = request_with_retry(build_body(prompt, images, response_schema))
      parse_response(response)
    end

    private

    # APIキーを環境変数から取得する
    #
    # nil だけでなく空文字も未設定として扱う（環境変数を空のまま残した場合に、
    # 空のキーで API を叩いて 401 になるのを防ぐ）。
    #
    # @return [String]
    # @raise [ApiError] 未設定の場合
    def api_key
      ENV["GEMINI_API_KEY"].presence ||
        raise(ApiError, "環境変数 GEMINI_API_KEY が設定されていません")
    end

    # リクエストボディを組み立てる
    #
    # 画像は inline_data（Base64）で埋め込む。temperature: 0 で結果を安定させる。
    # caption があれば、その画像の直前にテキストパートとして置く。
    #
    # @param prompt [String] プロンプト本文
    # @param images [Array<Hash>] 画像の配列（:caption, :mime_type, :data）
    # @param response_schema [Hash] 構造化出力のスキーマ
    # @return [Hash] リクエストボディ
    def build_body(prompt, images, response_schema)
      parts = [ { text: prompt } ]
      images.each do |image|
        parts << { text: image[:caption] } if image[:caption].present?
        parts << { inline_data: { mime_type: image[:mime_type], data: Base64.strict_encode64(image[:data]) } }
      end

      {
        contents: [ { parts: parts } ],
        generationConfig: {
          temperature: 0,
          responseMimeType: "application/json",
          responseSchema: response_schema
        }
      }
    end

    # 全体デッドライン方式でリトライする
    #
    # リトライは「開始から TOTAL_TIMEOUT 秒まで」という締め切りの中だけで行う。
    # 締め切りが無いと、Gemini 側が無応答のときに
    # READ_TIMEOUT × 試行回数 ぶん待たされてしまう。
    #
    # 失敗の種類でリトライ有無を変更
    # - 4xx/5xx が即座に返る場合: サーバーが応答しているので、待ってから再送する
    # - 無応答（タイムアウト）の場合: 既に長く待っているので、追加の待機はせず次の試行へ進む
    # - 接続に失敗した場合: すぐに返ってくるので、4xx/5xx と同じく待ってから再送する
    #
    # @param body [Hash] リクエストボディ
    # @return [Net::HTTPSuccess] 成功レスポンス
    # @raise [ApiError] 締め切りまでに成功しなかった場合
    def request_with_retry(body)
      deadline = current_time + TOTAL_TIMEOUT
      last_error_message = nil

      (MAX_RETRIES + 1).times do |attempt|
        remaining = deadline - current_time
        # 残り時間が短すぎるなら、投げても間に合わないので諦める
        break if remaining < MIN_ATTEMPT_SECONDS

        begin
          # 残り時間が READ_TIMEOUT より短ければ、そちらに合わせて切り詰める
          response = post_request(body, read_timeout: [ READ_TIMEOUT, remaining ].min)
        rescue Net::OpenTimeout, Net::ReadTimeout
          # 既に read_timeout ぶん待っているため、追加の待機はせず次の試行へ
          last_error_message = "Gemini API がタイムアウトしました"
          next
        rescue *CONNECTION_ERRORS => e
          # タイムアウトと違ってすぐに返ってくるので、待ってから再送する
          last_error_message = "Gemini API との通信に失敗しました（#{e.class}）"
          sleep(RETRY_WAIT_SECONDS[attempt]) if attempt < MAX_RETRIES
          next
        end

        return response if response.is_a?(Net::HTTPSuccess)

        unless RETRYABLE_STATUSES.include?(response.code.to_i)
          raise ApiError, "Gemini API エラー（ステータス: #{response.code}）"
        end

        last_error_message = "Gemini API エラー（ステータス: #{response.code}）"
        sleep(RETRY_WAIT_SECONDS[attempt]) if attempt < MAX_RETRIES
      end

      # last_error_message が nil のまま到達するのは、最初の試行の時点で
      # 残り時間が MIN_ATTEMPT_SECONDS を切っていて、1回もリクエストせずに
      # break した場合だけ（テストで TOTAL_TIMEOUT を 0 にした場合など）
      raise ApiError, last_error_message || "Gemini API の制限時間内に処理を開始できませんでした"
    end

    # generateContent へPOSTする
    # @param body [Hash] リクエストボディ
    # @param read_timeout [Numeric] レスポンスを待つ秒数
    # @return [Net::HTTPResponse]
    def post_request(body, read_timeout:)
      url = URI.parse("#{BASE_URL}/v1beta/models/#{@model}:generateContent")

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = read_timeout

      request = Net::HTTP::Post.new(url.request_uri)
      request["x-goog-api-key"] = api_key
      request["Content-Type"] = "application/json"
      request.body = body.to_json

      http.request(request)
    end

    # 経過時間の計測に使う現在時刻（秒）
    #
    # Time.current ではなく単調増加時計を使う。
    # NTPによる時刻補正が入っても巻き戻らないため、締め切りの判定が狂わない。
    #
    # @return [Float]
    def current_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    # レスポンスを検証し、構造化出力のJSONをHashにして返す
    # @param response [Net::HTTPSuccess] 成功レスポンス
    # @return [Hash] 抽出結果（シンボルキー）
    # @raise [ApiError] ブロック・生成中断・JSON不正の場合
    def parse_response(response)
      json = JSON.parse(response.body)

      # 安全性フィルタ等で入力自体が拒否された場合は candidates が返らない
      block_reason = json.dig("promptFeedback", "blockReason")
      raise ApiError, "リクエストがブロックされました（理由: #{block_reason}）" if block_reason.present?

      candidate = json.dig("candidates", 0)
      raise ApiError, "Gemini API から結果が返りませんでした" if candidate.nil?

      # STOP 以外（MAX_TOKENS 等）は生成が途中で打ち切られている
      finish_reason = candidate["finishReason"]
      raise ApiError, "生成が中断されました（理由: #{finish_reason}）" unless finish_reason == "STOP"

      @last_usage = json["usageMetadata"]

      text = candidate.dig("content", "parts", 0, "text")
      raise ApiError, "Gemini API のレスポンスにテキストが含まれていません" if text.blank?

      JSON.parse(text, symbolize_names: true)
    rescue JSON::ParserError
      raise ApiError, "Gemini API のレスポンスをJSONとして解釈できませんでした"
    end
  end
end
