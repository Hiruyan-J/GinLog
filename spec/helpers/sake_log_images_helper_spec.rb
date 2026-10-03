require "rails_helper"

RSpec.describe SakeLogImagesHelper, type: :helper do
  let(:area) { create(:area, name: "三重県") }
  let(:brewery) { create(:brewery, name: "木屋正酒造", area: area) }
  let(:brand) { create(:brand, name: "而今", brewery: brewery) }
  let(:sake) { create(:sake, product_name: "純米吟醸", brand: brand) }
  let(:sake_log) { create(:sake_log, sake: sake, rating: 3) }

  describe "#sake_log_ogp_image_url" do
    context "保存先が Cloudinary でないとき（テスト環境）" do
      it "静的OGP画像の絶対 URL を返す" do
        url = helper.sake_log_ogp_image_url(sake_log)

        expect(url).to start_with "http://test.host/"
        expect(url).to include "ginlog_ogp"
      end
    end

    context "保存先が Cloudinary のとき" do
      # テスト環境には Cloudinary の接続情報が無いため、cloud_name だけ仮の値を入れる
      around do |example|
        original_cloud_name = Cloudinary.config.cloud_name
        Cloudinary.config(cloud_name: "test-cloud")
        example.run
      ensure
        Cloudinary.config(cloud_name: original_cloud_name)
      end

      before do
        allow(helper).to receive(:cloudinary_storage?).and_return(true)
      end

      it "ラベル写真があれば、その写真をもとにした jpg の URL を返す" do
        sake_log.front_label_image.attach(fixture_file_upload("test_label.jpg", "image/jpeg"))

        url = helper.sake_log_ogp_image_url(sake_log)

        expect(url).to start_with "https://res.cloudinary.com/test-cloud/image/upload/"
        expect(url).to include "/#{sake_log.front_label_image.blob.key}.jpg"
      end

      it "ラベル写真がなければ、土台画像をもとにした URL を返す" do
        url = helper.sake_log_ogp_image_url(sake_log)

        expect(url).to include "/#{SakeLogImagesHelper::OGP_BASE_PUBLIC_ID}.jpg"
      end


      it "銘柄名・商品名・蔵元名・都道府県・好み度（★）が文字として重なる" do
        url = helper.sake_log_ogp_image_url(sake_log)

        expect(url).to include ERB::Util.url_encode("而今")
        expect(url).to include ERB::Util.url_encode("純米吟醸")
        expect(url).to include ERB::Util.url_encode("(木屋正酒造 - 三重県)")
        expect(url).to include ERB::Util.url_encode("★★★☆☆")
      end

      it "蔵元名が「(名称不明)」なら、都道府県だけを載せる" do
        brewery.update!(name: "(名称不明)")

        url = helper.sake_log_ogp_image_url(sake_log)

        expect(url).to include ERB::Util.url_encode("(三重県)")
        expect(url).not_to include ERB::Util.url_encode("名称不明")
      end

      it "URL に空白が含まれない（フォント名の空白は %20 になる）" do
        url = helper.sake_log_ogp_image_url(sake_log)

        expect(url).not_to include " "
        expect(url).to include "Sawarabi%20Gothic"
      end
    end
  end
end
