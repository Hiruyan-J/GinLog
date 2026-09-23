require "rails_helper"

RSpec.describe LabelExtraction::GeminiClient do
  let(:model) { "gemini-test-model" }
  let(:client) { described_class.new(model: model) }
  let(:endpoint) { %r{generativelanguage\.googleapis\.com/v1beta/models/.+:generateContent} }
  let(:prompt) { "テストプロンプト" }
  let(:images) { [ { caption: "画像の説明", mime_type: "image/jpeg", data: "dummy-binary" } ] }
  let(:response_schema) { { type: "OBJECT" } }
  let(:extraction) { { brand_name: "屋守", product_name: "純米中取り 無調整生" } }

  before do
    # MODELの環境変数に値が入ったままだと「環境変数が無ければ既定」のテストが落ちる
    ENV.delete("GEMINI_MODEL")
    ENV.delete("GEMINI_FALLBACK_MODEL")
    ENV["GEMINI_API_KEY"] = "test-api-key"
    # テストではリトライの待ち時間をゼロにする
    stub_const("#{described_class}::RETRY_WAIT_SECONDS", [ 0, 0 ])
  end

  after do
    ENV.delete("GEMINI_API_KEY")
    # モデル指定を次のテストへ持ち越さない
    ENV.delete("GEMINI_MODEL")
    ENV.delete("GEMINI_FALLBACK_MODEL")
  end

  # Gemini API の成功レスポンスのボディを組み立てる
  # @param payload [Hash] 構造化出力として返す抽出結果
  # @return [String] レスポンスボディ（JSON）
  def success_body(payload = extraction)
    {
      candidates: [
        { content: { parts: [ { text: payload.to_json } ] }, finishReason: "STOP" }
      ],
      usageMetadata: { promptTokenCount: 2000, candidatesTokenCount: 70 }
    }.to_json
  end

  describe "#generate" do
    it "抽出結果をシンボルキーのHashで返す" do
      stub_request(:post, endpoint).to_return(status: 200, body: success_body)

      result = client.generate(prompt: prompt, images: images, response_schema: response_schema)

      expect(result).to eq(extraction)
    end

    it "APIキーのヘッダと、説明つきのBase64化した画像を含むリクエストを送る" do
      stub = stub_request(:post, endpoint)
              .with(headers: { "x-goog-api-key" => "test-api-key" }) { |request|
                body = JSON.parse(request.body)
                parts = body.dig("contents", 0, "parts")
                parts[0]["text"] == prompt &&
                  parts[1]["text"] == "画像の説明" &&
                  parts[2].dig("inline_data", "data") == Base64.strict_encode64("dummy-binary") &&
                  body.dig("generationConfig", "responseMimeType") == "application/json"
              }
              .to_return(status: 200, body: success_body)

      client.generate(prompt: prompt, images: images, response_schema: response_schema)

      expect(stub).to have_been_requested
    end

    it "画像が複数のときは、説明と画像を交互に並べて送る" do
      multiple_images = [
        { caption: "1枚目の説明", mime_type: "image/jpeg", data: "first-binary" },
        { caption: "2枚目の説明", mime_type: "image/jpeg", data: "second-binary" }
      ]
      stub = stub_request(:post, endpoint)
              .with { |request|
                parts = JSON.parse(request.body).dig("contents", 0, "parts")
                parts.size == 5 &&
                  parts[1]["text"] == "1枚目の説明" &&
                  parts[2].dig("inline_data", "data") == Base64.strict_encode64("first-binary") &&
                  parts[3]["text"] == "2枚目の説明" &&
                  parts[4].dig("inline_data", "data") == Base64.strict_encode64("second-binary")
              }
              .to_return(status: 200, body: success_body)

      client.generate(prompt: prompt, images: multiple_images, response_schema: response_schema)

      expect(stub).to have_been_requested
    end

    it "一時エラー(503)のあとに成功したらリトライして結果を返す" do
      stub_request(:post, endpoint)
        .to_return(status: 503)
        .then.to_return(status: 200, body: success_body)

        result = client.generate(prompt: prompt, images: images, response_schema: response_schema)

        expect(result).to eq(extraction)
    end

    it "リトライ上限まで失敗したら ApiError を投げる" do
      stub_request(:post, endpoint).to_return(status: 503)

      expect {
        client.generate(prompt: prompt, images: images, response_schema: response_schema)
      }.to raise_error(described_class::ApiError, /503/)
    end

    it "安全性フィルタでブロックされたら ApiError を投げる" do
      stub_request(:post, endpoint)
        .to_return(status: 200, body: { promptFeedback: { blockReason: "SAFETY" } }.to_json)

      expect {
        client.generate(prompt: prompt, images: images, response_schema: response_schema)
      }.to raise_error(described_class::ApiError, /ブロック/)
    end

    it "生成がSTOP以外で終わったら ApiError を投げる" do
      body = {
        candidates: [ { content: { parts: [ { text: "{}" } ] }, finishReason: "MAX_TOKENS" } ]
      }.to_json
      stub_request(:post, endpoint).to_return(status: 200, body: body)

      expect {
        client.generate(prompt: prompt, images: images, response_schema: response_schema)
      }.to raise_error(described_class::ApiError, /中断/)
    end

    it "candidates が空なら ApiError を投げる" do
      stub_request(:post, endpoint).to_return(status: 200, body: { candidates: [] }.to_json)

      expect {
        client.generate(prompt: prompt, images: images, response_schema: response_schema)
      }.to raise_error(described_class::ApiError, /結果が返りません/)
    end

    it "テキストが空なら ApiError を投げる" do
      body = { candidates: [ { content: { parts: [ { text: "" } ] }, finishReason: "STOP" } ] }.to_json
      stub_request(:post, endpoint).to_return(status: 200, body: body)

      expect {
        client.generate(prompt: prompt, images: images, response_schema: response_schema)
      }.to raise_error(described_class::ApiError, /テキストが含まれていません/)
    end

    it "テキストがJSONとして壊れていたら ApiError を投げる" do
      body = { candidates: [ { content: { parts: [ { text: "{壊れたJSON" } ] }, finishReason: "STOP" } ] }.to_json
      stub_request(:post, endpoint).to_return(status: 200, body: body)

      expect {
        client.generate(prompt: prompt, images: images, response_schema: response_schema)
      }.to raise_error(described_class::ApiError, /JSONとして解釈できません/)
    end

    it "APIキーが未設定なら ApiError を投げる" do
      ENV.delete("GEMINI_API_KEY")

      expect {
        client.generate(prompt: prompt, images: images, response_schema: response_schema)
      }.to raise_error(described_class::ApiError, /GEMINI_API_KEY/)
    end

    it "APIキーが空文字なら未設定として ApiError を投げる" do
      ENV["GEMINI_API_KEY"] = ""

      expect {
        client.generate(prompt: prompt, images: images, response_schema: response_schema)
      }.to raise_error(described_class::ApiError, /GEMINI_API_KEY/)
    end
  end

  describe "タイムアウトの扱い" do
    it "タイムアウトが続いたら、上限回数まで試してから ApiError を投げる" do
      stub_request(:post, endpoint).to_raise(Net::ReadTimeout)

      expect {
        client.generate(prompt: prompt, images: images, response_schema: response_schema)
      }.to raise_error(described_class::ApiError, /タイムアウト/)
      expect(a_request(:post, endpoint)).to have_been_made.times(described_class::MAX_RETRIES + 1)
    end

    it "接続の確立に失敗した場合もタイムアウトとして扱う" do
      stub_request(:post, endpoint).to_raise(Net::OpenTimeout)

      expect {
        client.generate(prompt: prompt, images: images, response_schema: response_schema)
      }.to raise_error(described_class::ApiError, /タイムアウト/)
      expect(a_request(:post, endpoint)).to have_been_made.times(described_class::MAX_RETRIES + 1)
    end

    it "全体の制限時間を使い切っていたら、リクエストせずに諦める" do
      stub_const("#{described_class}::TOTAL_TIMEOUT", 0)
      stub = stub_request(:post, endpoint).to_return(status: 200, body: success_body)

      expect {
        client.generate(prompt: prompt, images: images, response_schema: response_schema)
      }.to raise_error(described_class::ApiError, /制限時間内に処理を開始できませんでした/)
      expect(stub).not_to have_been_requested
    end
  end

  describe "接続エラーの扱い" do
    it "DNSの解決に失敗した場合、ApiError に変換する" do
      stub_request(:post, endpoint).to_raise(SocketError)

      expect {
        client.generate(prompt: prompt, images: images, response_schema: response_schema)
      }.to raise_error(described_class::ApiError, /通信に失敗しました/)
      expect(a_request(:post, endpoint)).to have_been_made.times(described_class::MAX_RETRIES + 1)
    end

    it "接続を拒否された場合、ApiError に変換する" do
      stub_request(:post, endpoint).to_raise(Errno::ECONNREFUSED)

      expect {
        client.generate(prompt: prompt, images: images, response_schema: response_schema)
      }.to raise_error(described_class::ApiError, /通信に失敗しました/)
    end

    it "SSLのエラー時に、ApiError に変換する" do
      stub_request(:post, endpoint).to_raise(OpenSSL::SSL::SSLError)

      expect {
        client.generate(prompt: prompt, images: images, response_schema: response_schema)
      }.to raise_error(described_class::ApiError, /通信に失敗しました/)
    end
  end

  describe "使用するモデル" do
    it "指定したモデルのエンドポイントへ送る" do
      stub = stub_request(:post, %r{/v1beta/models/#{Regexp.escape(model)}:generateContent})
              .to_return(status: 200, body: success_body)

      client.generate(prompt: prompt, images: images, response_schema: response_schema)

      expect(stub).to have_been_requested
    end
  end

  describe ".models" do
    it "環境変数が無ければ既定の本命→退避の順に返す" do
      expect(described_class.models)
        .to eq([ described_class::PRIMARY_MODEL, described_class::FALLBACK_MODEL ])
    end

    it "環境変数が指定されていればそれを使う" do
      ENV["GEMINI_MODEL"] = "gemini-3.5-flash-lite"
      ENV["GEMINI_FALLBACK_MODEL"] = "gemini-2.5-flash-lite"

      expect(described_class.models).to eq([ "gemini-3.5-flash-lite", "gemini-2.5-flash-lite" ])
    end

    it "環境変数が空文字なら既定値へ落とす" do
      ENV["GEMINI_MODEL"] = ""
      ENV["GEMINI_FALLBACK_MODEL"] = ""

      expect(described_class.models)
        .to eq([ described_class::PRIMARY_MODEL, described_class::FALLBACK_MODEL ])
    end

    it "本命と退避が同じなら1つにまとめる" do
      ENV["GEMINI_MODEL"] = "gemini-3.5-flash-lite"
      ENV["GEMINI_FALLBACK_MODEL"] = "gemini-3.5-flash-lite"

      expect(described_class.models).to eq([ "gemini-3.5-flash-lite" ])
    end
  end

  describe ".generate_with_fallback" do
    let(:primary) { "gemini-primary-test" }
    let(:fallback) { "gemini-fallback-test" }

    before do
      ENV["GEMINI_MODEL"] = primary
      ENV["GEMINI_FALLBACK_MODEL"] = fallback
    end

    # 特定モデルのURLだけにマッチするパターンを作る
    # @param model_name [String] モデル名
    # @return [Regexp]
    def endpoint_for(model_name)
      %r{/v1beta/models/#{Regexp.escape(model_name)}:generateContent}
    end

    # @return [Hash] generate_with_fallback へ渡す引数
    def args
      { prompt: prompt, images: images, response_schema: response_schema }
    end

    it "本命が成功したらその結果を返し、退避モデルは呼ばない" do
      stub_request(:post, endpoint_for(primary)).to_return(status: 200, body: success_body)

      expect(described_class.generate_with_fallback(**args)).to eq(extraction)
      expect(a_request(:post, endpoint_for(fallback))).not_to have_been_made
    end

    it "本命が失敗したら退避モデルの結果を返す" do
      stub_request(:post, endpoint_for(primary)).to_return(status: 500)
      stub_request(:post, endpoint_for(fallback)).to_return(status: 200, body: success_body)

      expect(described_class.generate_with_fallback(**args)).to eq(extraction)
      expect(a_request(:post, endpoint_for(fallback))).to have_been_made
    end

    it "本命が通信エラーになっても退避モデルを試す" do
      stub_request(:post, endpoint_for(primary)).to_raise(SocketError)
      stub_request(:post, endpoint_for(fallback)).to_return(status: 200, body: success_body)

      expect(described_class.generate_with_fallback(**args)).to eq(extraction)
      expect(a_request(:post, endpoint_for(fallback))).to have_been_made
    end

    it "すべて失敗したら、どのモデルで何が起きたかを含めて ApiError を投げる" do
      stub_request(:post, endpoint_for(primary)).to_return(status: 500)
      stub_request(:post, endpoint_for(fallback)).to_return(status: 500)

      expect {
        described_class.generate_with_fallback(**args)
      }.to raise_error(described_class::ApiError, /#{primary}.+#{fallback}/m)
    end

    it "本命と退避が同じモデルなら1回ぶんしか試さない" do
      ENV["GEMINI_FALLBACK_MODEL"] = primary
      stub_request(:post, endpoint_for(primary)).to_return(status: 500)

      expect {
        described_class.generate_with_fallback(**args)
      }.to raise_error(described_class::ApiError)
      # 500 はモデル内で3回まで再送されるため、その回数で収まることを見る
      expect(a_request(:post, endpoint_for(primary)))
        .to have_been_made.times(described_class::MAX_RETRIES + 1)
    end
  end
end
