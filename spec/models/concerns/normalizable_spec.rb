require "rails_helper"

RSpec.describe Normalizable do
  describe ".normalize_text" do
    context "NFKC 正規化" do
      it "全角英数字を半角に変換する" do
        expect(Normalizable.normalize_text "ＡＢＣ１２３").to eq "ABC123"
      end

      it "全角スペースを半角スペースに変換する" do
        full_width_space = "　" # 全角スペース
        expect(Normalizable.normalize_text "新政#{full_width_space}酒造").to eq "新政 酒造"
      end

      it "半角カナを全角カナに変換する" do
        expect(Normalizable.normalize_text("ﾀｶﾁﾖ")).to eq "タカチヨ"
      end
    end

    context "ハイフン・ダッシュ・マイナス類の統一" do
      it "各種ダッシュ(U+2010〜U+2015)を半角ハイフンに統一する" do
        (0x2010..0x2015).each do |code_point|
          dash = code_point.chr(Encoding::UTF_8)

          expect(Normalizable.normalize_text("A#{dash}B")).to eq "A-B"
        end
      end

      it "マイナス記号(U+2212)を半角ハイフンに統一する" do
        minus = 0x2212.chr(Encoding::UTF_8) # − MINUS SIGN

        expect(Normalizable.normalize_text("A#{minus}B")).to eq "A-B"
      end

      it "小書きダッシュ(U+FE58 / U+FE63)を半角ハイフンに統一する" do
        small_em_dash      = 0xFE58.chr(Encoding::UTF_8) # ﹘ SMALL EM DASH
        small_hyphen_minus = 0xFE63.chr(Encoding::UTF_8) # ﹣ SMALL HYPHEN-MINUS

        expect(Normalizable.normalize_text("A#{small_em_dash}B")).to eq "A-B"
        expect(Normalizable.normalize_text("A#{small_hyphen_minus}B")).to eq "A-B"
      end
    end

    context "長音「ー」(U+30FC) の保護" do
      it "長音はハイフンに変換されない" do
        long_vowel = "ー" # ー 長音記号(U+30FC)

        expect(Normalizable.normalize_text("ビール")).to eq "ビール"
        expect(Normalizable.normalize_text("ビール")).to include(long_vowel)
      end
    end

    context "空白の圧縮・strip" do
      it "連続する空白を1つに圧縮し、前後の空白を除去する" do
        expect(Normalizable.normalize_text("  獺祭   純米   ")).to eq "獺祭 純米"
      end
    end

    context "nil" do
      it "nil はそのまま nil を返す" do
        expect(Normalizable.normalize_text(nil)).to be_nil
      end
    end
  end
end
