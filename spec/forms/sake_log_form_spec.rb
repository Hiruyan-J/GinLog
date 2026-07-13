require "rails_helper"

RSpec.describe SakeLogForm, type: :model do
  # 通常モードで使う既存の蔵元・銘柄
  let(:user) { create(:user) }
  let(:brewery) { create(:brewery) }
  let(:brand) { create(:brand, brewery: brewery) }

  # 有効な属性で SakeLogForm を組み立てるヘルパー(必要な値だけ overrides で差し替える)
  def build_form(overrides = {})
    attributes = {
      product_name: "テスト純米吟醸",
      brand_id: brand.id,
      rating: 3,
      aroma_strength: 5.0,
      taste_strength: 5.0,
      review: "華やかな香り"
    }.merge(overrides)
    SakeLogForm.new(attributes, user: user)
  end

  # ------------------------------------------------------------------
  # バリデーション
  # ------------------------------------------------------------------
  describe "バリデーション" do
    subject { build_form }

    it { is_expected.to be_valid }

    # shoulda-matchers で presence を簡潔に確認
    it { is_expected.to validate_presence_of(:rating) }
    it { is_expected.to validate_presence_of(:product_name) }
    it { is_expected.to validate_presence_of(:aroma_strength) }
    it { is_expected.to validate_presence_of(:taste_strength) }

    context "rating の境界値" do
      it "下限・上限は有効" do
        [ SakeLog::RATING_MIN, SakeLog::RATING_MAX ].each do |value|
          expect(build_form(rating: value)).to be_valid
        end
      end

      it "範囲外は無効" do
        [ SakeLog::RATING_MIN - 1, SakeLog::RATING_MAX + 1 ].each do |value|
          expect(build_form(rating: value)).to be_invalid
        end
      end
    end

    context "aroma_strength の境界値" do
      it "下限・上限は有効" do
        [ SakeLog::AROMA_STRENGTH_MIN, SakeLog::AROMA_STRENGTH_MAX ].each do |value|
          expect(build_form(aroma_strength: value)).to be_valid
        end
      end

      it "範囲外は無効" do
        [ SakeLog::AROMA_STRENGTH_MIN - 0.1, SakeLog::AROMA_STRENGTH_MAX + 0.1 ].each do |value|
          expect(build_form(aroma_strength: value)).to be_invalid
        end
      end
    end

    context "taste_strength の境界値" do
      it "下限・上限は有効" do
        [ SakeLog::TASTE_STRENGTH_MIN, SakeLog::TASTE_STRENGTH_MAX ].each do |value|
          expect(build_form(taste_strength: value)).to be_valid
        end
      end

      it "範囲外は無効" do
        [ SakeLog::TASTE_STRENGTH_MIN - 0.1, SakeLog::TASTE_STRENGTH_MAX + 0.1 ].each do |value|
          expect(build_form(taste_strength: value)).to be_invalid
        end
      end
    end

    context "review の文字数" do
      it "空でも有効(任意項目)" do
        expect(build_form(review: "")).to be_valid
      end
    end

    # 条件付きバリデーション: 手入力モード時のみ必須になる項目
    # - manual_brand_name   : brand_id が blank（手入力モード）のとき必須
    # - manual_brewery_name : brand_id かつ brewery_id が blank（蔵元手入力モード）のとき必須
    # - area_id             : 同上
    describe "条件付きバリデーション(手入力モード)" do
      context "銘柄も蔵元も手入力（brand_id / brewery_id とも未指定）" do
        it "manual_brand_name / manual_brewery_name / area_id が必要" do
          form = SakeLogForm.new(
            { product_name: "x", rating: 3, aroma_strength: 5.0, taste_strength: 5.0 },
            user: user
          )

          expect(form).to be_invalid
          expect(form.errors[:manual_brand_name]).to be_present
          expect(form.errors[:manual_brewery_name]).to be_present
          expect(form.errors[:area_id]).to be_present
        end
      end

      context "蔵元選択モード（brewery_id あり / brand_id なし）" do
        it "manual_brand_name のみ必須で、manual_brewery_name / area_id は不要" do
          form = SakeLogForm.new(
            {
              product_name: "x", rating: 3, aroma_strength: 5.0, taste_strength: 5.0,
              brewery_id: brewery.id
            },
            user: user
          )

          expect(form).to be_invalid
          expect(form.errors[:manual_brand_name]).to be_present
          expect(form.errors[:manual_brewery_name]).to be_blank
          expect(form.errors[:area_id]).to be_blank
        end
      end
    end
  end

  # ------------------------------------------------------------------
  # #save
  # ------------------------------------------------------------------
  describe "#save" do
    context "通常モード (brand 既存選択 / sake 既存選択)" do
      it "新たな Sake は作らず、既存 Sake に紐づく SakeLog を作る" do
        selected_sake = create(:sake, brand: brand, product_name: "既存酒")
        form = build_form(product_name: "既存酒", sake_id: selected_sake.id)

        expect { form.save }
          .to change(SakeLog, :count).by(1)
          .and change(Sake, :count).by(0)
        expect(form.sake_log.sake).to eq selected_sake
      end

      it "保存に成功すると true を返す" do
        expect(build_form.save).to be true
      end
    end

    context "通常モード (brand 既存選択 / sake 新規作成)" do
      it "Sake と SakeLog が1件ずつ作成される" do
        selected_brand = brand
        form = build_form(brand_id: selected_brand.id)

        expect { form.save }
          .to change(Sake, :count).by(1)
          .and change(SakeLog, :count).by(1)
          .and change(Brand, :count).by(0)
        expect(form.sake_log.sake.brand).to eq selected_brand
      end
    end

    context "手入力モード（brand 新規作成 / brewery 新規作成 / area 既存選択）" do
      let(:area) { create(:area) }

      it "Brewery / Brand / Sake / SakeLog がすべて新規作成される" do
        attributes = {
          product_name: "手入力純米",
          manual_brand_name: "新政",
          manual_brewery_name: "新政酒造",
          area_id: area.id,
          rating: 4,
          aroma_strength: 6.0,
          taste_strength: 4.0
        }
        form = SakeLogForm.new(attributes, user: user)

        expect { form.save }
          .to change(Brewery, :count).by(1)
          .and change(Brand, :count).by(1)
          .and change(Sake, :count).by(1)
          .and change(SakeLog, :count).by(1)
      end
    end

    context "手入力モード（brand 新規作成 / brewery 既存選択）" do
      it "既存 Brewery を使い、Brand を新規作成する" do
        selected_brewery = create(:brewery)
        attributes = {
          product_name: "蔵元選択酒",
          manual_brand_name: "新規銘柄",
          brewery_id: selected_brewery.id,
          rating: 3,
          aroma_strength: 5.0,
          taste_strength: 5.0
        }
        form = SakeLogForm.new(attributes, user: user)

        expect { form.save }
          .to change(Brand, :count).by(1)
          .and change(Brewery, :count).by(0)
        expect(form.sake_log.sake.brand.brewery).to eq selected_brewery
      end
    end

    context "同一商品名・銘柄で繰り返し保存したとき" do
      it "Sake は重複作成されない(2回目は SakeLog のみ増える)" do
        build_form(product_name: "重複テスト酒").save

        expect {
          build_form(product_name: "重複テスト酒").save
      }.to change(SakeLog, :count).by(1)
       .and change(Sake, :count).by(0)
      end
    end

    # find_or_create_brewery! / find_or_create_brand! が
    # 「既存レコードがあれば再利用し、二重登録しない」ことを独立して検証する。
    context "重複レコードの再利用（既存があれば新規作成しない）" do
      let(:area) { create(:area) }

      it "蔵元手入力: 同名・同都道府県の Brewery が既存なら再利用する" do
        existing_brewery = create(:brewery, name: "赤武酒造", area: area)

        form = SakeLogForm.new(
          {
            product_name: "純米酒",
            manual_brand_name: "新規銘柄",  # 銘柄は新規（Brand は増える）
            manual_brewery_name: "赤武酒造",
            area_id: area.id,
            rating: 3, aroma_strength: 5.0, taste_strength: 5.0
          },
          user: user
        )

        expect { form.save }.to change(Brewery, :count).by(0)
        expect(form.sake_log.sake.brand.brewery).to eq existing_brewery
      end

      it "銘柄手入力: 同名・同蔵元の Brand が既存なら再利用する" do
        existing_brewery = create(:brewery, name: "赤武酒造", area: area)
        existing_brand = create(:brand, name: "赤武", brewery: existing_brewery)

        form = SakeLogForm.new(
          {
            product_name: "純米酒",
            manual_brand_name: "赤武",
            manual_brewery_name: "赤武酒造",
            area_id: area.id,
            rating: 3, aroma_strength: 5.0, taste_strength: 5.0
          },
          user: user
        )

        expect { form.save }.to change(Brand, :count).by(0)
        expect(form.sake_log.sake.brand).to eq existing_brand
      end
    end

    context "編集（既存 sake_log を渡す）" do
      it "rating を更新できる" do
        sake_log = create(:sake_log, rating: 2)
        form = SakeLogForm.new({ rating: 5 }, user: sake_log.user, sake_log: sake_log)

        expect(form.save).to be true
        expect(sake_log.reload.rating).to eq 5
      end
    end

    context "バリデーションエラー時" do
      it "save は false を返し errors に転記される" do
        form = SakeLogForm.new({ product_name: "x", brand_id: brand.id }, user: user)

        expect(form.save).to be false
        expect(form.errors[:rating]).to be_present
      end

      it "Sake / SakeLog は作成されない" do
        form = SakeLogForm.new({ product_name: "x", brand_id: brand.id }, user: user)

        expect { form.save }
          .to change(Sake, :count).by(0)
          .and change(SakeLog, :count).by(0)
      end
    end

    context "sake_id と brand_id が不整合のとき" do
      it ":base に「見つかりませんでした」が転記され false を返す" do
        other_brand = create(:brand)
        sake = create(:sake, brand: brand, product_name: "不整合酒")
        form = build_form(product_name: "不整合酒", brand_id: other_brand.id, sake_id: sake.id)

        expect(form.save).to be false
        expect(form.errors[:base]).to include("指定された日本酒が見つかりませんでした")
      end
    end

    context "正規化による重複防止" do
      let(:area) { create(:area) }

      it "表記揺れ（全角スペース等）があっても Brand / Brewery は重複作成されない" do
        common = {
          manual_brewery_name: "赤武酒造",
          area_id: area.id,
          product_name: "純米酒",
          rating: 3,
          aroma_strength: 5.0,
          taste_strength: 5.0
        }
        SakeLogForm.new(common.merge(manual_brand_name: "AKABU"), user: user).save

        # 「　ＡＫＡＢＵ　」（前後に全角スペース+全角）は NFKC 正規化 + strip で「AKABU」に揃う
        expect {
          SakeLogForm.new(common.merge(manual_brand_name: "　ＡＫＡＢＵ　"), user: user).save
      }.to change(Brand, :count).by(0)
       .and change(Brewery, :count).by(0)
      end
    end

    # 並行リクエストで別プロセスが先に同一 Sake を作成済みのとき、
    # sake.save! が RecordNotUnique を出し、rescue 内で既存レコードを再取得する。
    context "別リクエストが先に同一 Sake を作成済み（複合ユニーク制約違反）" do
      it "RecordNotUnique を捕捉し、既存 Sake に紐づけて保存できる" do
        # 先行リクエスト(A)が作成済みの Sake。rescue 内の Sake.find_by! で再取得される想定。
        existing = create(:sake, brand: brand, product_name: "制約テスト酒")

        # find_or_initialize_sake が未保存の新規 Sake を返す状況を作り(=リクエストBの視点)、
        # その new_sake の save! だけを失敗させる(existing.save! には一切触れない)。
        # rescue 内の Sake.find_by! はスタブしないので、本物の DB から existing を引く。
        new_sake = Sake.new(product_name: "制約テスト酒", brand_id: brand.id)
        expect(Sake).to receive(:find_or_initialize_by)
          .with(product_name: "制約テスト酒", brand_id: brand.id)
          .and_return(new_sake)
        allow(new_sake).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique)

        form = build_form(product_name: "制約テスト酒", brand_id: brand.id)

        expect { form.save }.to change(SakeLog, :count).by(1)
        expect(form.sake_log.sake).to eq existing
      end
    end
  end
end
