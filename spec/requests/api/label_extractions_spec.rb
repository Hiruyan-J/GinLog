require 'rails_helper'

RSpec.describe "Api::LabelExtractions", type: :request do
  let(:user) { create(:user) }
  let(:endpoint) { %r{generativelanguage\.googleapis\.com/v1beta/models/.+:generateContent} }
  let(:front_image) { fixture_file_upload("test_label.jpg", "image/jpeg") }
  let(:back_image) { fixture_file_upload("test_label.jpg", "image/jpeg") }

  before do
    ENV["GEMINI_API_KEY"] = "test-api-key"
    sign_in user
  end

  after do
    ENV.delete("GEMINI_API_KEY")
  end

  # Gemini API が extraction を返すようにスタブする
  # @param extraction [Hash] 抽出結果として返す内容
  # @return [void]
  def stub_gemini(extraction)
    body = {
      candidates: [
        { content: { parts: [ { text: extraction.to_json } ] }, finishReason: "STOP" }
      ]
    }.to_json
    stub_request(:post, endpoint).to_return(status: 200, body: body)
  end

  describe "POST /api/label_extraction" do
    context "読み取りに成功する場合" do
      let!(:brand) do
        create(:brand, name: "屋守",
               brewery: create(:brewery, name: "豊島屋酒造", area: create(:area, name: "東京都")))
      end

      before do
        stub_gemini(
          brand_name: "屋守", product_name: "純米中取り 無調整生",
          product_name_alternatives: [ "純米中取り 生酒" ],
          brewery_name: "豊島屋酒造", brewery_name_raw: "豊島屋酒造株式会社",
          prefecture: "東京都", confidence: "high"
        )
      end

      it "抽出結果と照合結果と残り回数を返す" do
        post api_label_extraction_path, params: { front_label_image: front_image }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["extraction"]["brand_name"]).to eq("屋守")
        expect(json["extraction"]["product_name_alternatives"]).to eq([ "純米中取り 生酒" ])
        expect(json["brand_match"]["status"]).to eq("single")
        expect(json["brand_match"]["candidates"][0]["id"]).to eq(brand.id)
        expect(json["remaining_count"]).to eq(LabelExtractionLog::DAILY_LIMIT - 1)
      end

      it "実行履歴が1件記録される" do
        expect {
          post api_label_extraction_path, params: { front_label_image: front_image }
        }.to change { user.label_extraction_logs.count }.by(1)
      end
    end

    context "裏ラベル画像だけを送った場合" do
      before do
        stub_gemini(
          brand_name: "屋守", product_name: "純米中取り 無調整生",
          product_name_alternatives: [ "純米中取り 生酒" ],
          brewery_name: "豊島屋酒造", brewery_name_raw: "豊島屋酒造株式会社",
          prefecture: "東京都", confidence: "high"
        )
      end

      it "読み取りに成功する" do
        post api_label_extraction_path, params: { back_label_image: back_image }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["extraction"]["brewery_name"]).to eq("豊島屋酒造")
      end

      it "裏ラベルとして Gemini に送る" do
        post api_label_extraction_path, params: { back_label_image: back_image }

        expect(a_request(:post, endpoint).with { |request|
          parts = JSON.parse(request.body).dig("contents", 0, "parts")
          parts.size == 3 && parts[1]["text"].include?("裏ラベル")
        }).to have_been_made
      end
    end

    context "画像が1枚もない場合" do
      it "422を返し、Gemini APIは呼ばれず回数も消費しない" do
        post api_label_extraction_path

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["error"]).to include("写真を選択してください")
        expect(a_request(:post, endpoint)).not_to have_been_made
        expect(user.label_extraction_logs.count).to eq(0)
      end
    end

    context "画像の合計サイズが上限を超える場合" do
      before do
        stub_const("Api::LabelExtractionsController::EXTRACTION_IMAGES_MAX_SIZE", 10)
      end

      it "422を返し、Gemini APIは呼ばれず回数も消費しない" do
        post api_label_extraction_path, params: { front_label_image: front_image }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["error"]).to include("大きすぎます")
        expect(a_request(:post, endpoint)).not_to have_been_made
        expect(user.label_extraction_logs.count).to eq(0)
      end
    end

    context "画像に見せかけた別形式のファイルが送られた場合" do
      before do
        # ブラウザは image/jpeg と申告しても、実体が画像でなければ弾く
        allow(Marcel::MimeType).to receive(:for).and_return("text/plain")
      end

      it "422を返し、Gemini APIは呼ばれず回数も消費しない" do
        post api_label_extraction_path, params: { front_label_image: front_image }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(a_request(:post, endpoint)).not_to have_been_made
        expect(user.label_extraction_logs.count).to eq(0)
      end
    end

    context "本日の上限に達している場合" do
      before do
        create_list(:label_extraction_log, LabelExtractionLog::DAILY_LIMIT, user: user)
      end

      it "429を返し、Gemini APIは呼ばれない" do
        post api_label_extraction_path, params: { front_label_image: front_image }

        expect(response).to have_http_status(:too_many_requests)
        expect(response.parsed_body["error"]).to include("上限")
        expect(a_request(:post, endpoint)).not_to have_been_made
      end
    end

    context "上限に達したのが前日の場合" do
      before do
        create_list(:label_extraction_log, LabelExtractionLog::DAILY_LIMIT,
                    user: user, executed_on: Date.current - 1)
        stub_gemini(
          brand_name: "屋守", product_name: "純米中取り 無調整生",
          product_name_alternatives: [ "純米中取り 生酒" ],
          brewery_name: "豊島屋酒造", brewery_name_raw: "豊島屋酒造株式会社",
          prefecture: "東京都", confidence: "high"
        )
      end

      it "日付が変わっているので実行できる" do
        post api_label_extraction_path, params: { front_label_image: front_image }

        expect(response).to have_http_status(:ok)
      end
    end

    context "Gemini APIがエラーを返し続ける場合" do
      before do
        stub_const("LabelExtraction::GeminiClient::RETRY_WAIT_SECONDS", [ 0, 0 ])
        stub_request(:post, endpoint).to_return(status: 500)
      end

      it "502とエラーメッセージを返す" do
        post api_label_extraction_path, params: { front_label_image: front_image }

        expect(response).to have_http_status(:bad_gateway)
        expect(response.parsed_body["error"]).to include("読み取りに失敗")
      end

      it "消費後の残り回数を返す" do
        post api_label_extraction_path, params: { front_label_image: front_image }

        expect(response.parsed_body["remaining_count"]).to eq(LabelExtractionLog::DAILY_LIMIT - 1)
        expect(user.label_extraction_logs.count).to eq(1)
      end
    end

    context "エラー応答の残り回数" do
      it "上限到達時は 0 を返す" do
        create_list(:label_extraction_log, LabelExtractionLog::DAILY_LIMIT, user: user)

        post api_label_extraction_path, params: { front_label_image: front_image }

        expect(response).to have_http_status(:too_many_requests)
        expect(response.parsed_body["remaining_count"]).to eq(0)
      end

      it "画像が1枚もない場合は、消費されていないので残り回数は減らない" do
        create_list(:label_extraction_log, 3, user: user)

        post api_label_extraction_path

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["remaining_count"]).to eq(LabelExtractionLog::DAILY_LIMIT - 3)
      end
    end

    context "未ログインの場合" do
      before { sign_out user }

      it "401を返す" do
        post api_label_extraction_path,
             params: { front_label_image: front_image },
             headers: { "Accept" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
