require "net/http"

module LabelExtraction
  # Gemini API の generateContent を呼び出す HTTP クライアント
  # モデルやプロンプトの内容には関知せず、通信とレスポンスの検証だけを担当する
  # @see https://ai.google.dev/gemini-api/docs
  class GeminiClient
    # API呼び出しの失敗（通信エラー・ブロック・不正レスポンス）を表す例外
    class ApiError < StandardError; end

    BASE_URL = "https://generativelanguage.googleapis.com"
    DEFAULT_MODEL = "gemini-3.7-flash"
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 60
    # リトライ回数と、各リトライ前の待ち時間（秒）
    MAX_RETRIES = 2
    RETRY_WAIT_SECONDS = [ 1, 2 ].freeze
    # リトライ対象のHTTPステータス（レート制限・サーバー側の一時エラー）
    RETRYABLE_STATUSES = [ 429, 500, 502, 503 ].freeze

    # 直近のAPI呼び出しのトークン使用量（評価タスクでコスト確認に使う）
    # @return [Hash, nil] 例: { "promptTokenCount" => 2375, "candidatesTokenCount" => 71 }
    attr_reader :last_usage

    # @param model [String] 使用するモデル名（環境変数 GEMINI_MODEL で上書き可能）
    def initialize(model: ENV.fetch("GEMINI_MODEL", DEFAULT_MODEL))
      @model = model
    end

    # 画像つきプロンプトを送り、構造化出力のJSONをHashで受け取る
    # @param prompt [String] プロンプト本文
    # @param images [Array<Hash>] 画像の配列。
    #   要素は { label: String, mime_type: String, data: String(バイナリ) }
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
    # 画像は inline_data（Base64）で埋め込む。temperature: 0 で結果を安定させる
    # @param prompt [String] プロンプト本文
    # @param images [Array<Hash>] 画像の配列（:label, :mime_type, :data）
    # @param response_schema [Hash] 構造化出力のスキーマ
    # @return [Hash] リクエストボディ
    def build_body(prompt, images, response_schema)
      parts = [ { text: prompt } ]
      images.each do |image|
        parts << { text: "次の画像は#{image[:label]}です。" }
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

    # 一時的なエラーならリトライしつつPOSTする
    # @param body [Hash] リクエストボディ
    # @return [Net::HTTPSuccess] 成功レスポンス
    # @raise [ApiError] リトライ上限まで失敗した場合
    def request_with_retry(body)
      (MAX_RETRIES + 1).times do |attempt|
        begin
          response = post_request(body)
        rescue Net::OpenTimeout, Net::ReadTimeout
          raise ApiError, "Gemini API がタイムアウトしました" if attempt >= MAX_RETRIES

          sleep(RETRY_WAIT_SECONDS[attempt])
          next
        end

        return response if response.is_a?(Net::HTTPSuccess)

        if RETRYABLE_STATUSES.include?(response.code.to_i) && attempt < MAX_RETRIES
          sleep(RETRY_WAIT_SECONDS[attempt])
          next
        end

        raise ApiError, "Gemini API エラー（ステータス: #{response.code}）"
      end
    end

    # generateContent へPOSTする
    # @param body [Hash] リクエストボディ
    # @return [Net::HTTPResponse]
    def post_request(body)
      url = URI.parse("#{BASE_URL}/v1beta/models/#{@model}:generateContent")

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = Net::HTTP::Post.new(url.request_uri)
      request["x-goog-api-key"] = api_key
      request["Content-Type"] = "application/json"
      request.body = body.to_json

      http.request(request)
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
