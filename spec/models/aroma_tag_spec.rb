require "rails_helper"

RSpec.describe AromaTag, type: :model do
  describe "バリデーション" do
    subject { build(:aroma_tag) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:position) }

    describe "名前の一意性（区分の中で）" do
      # validate_uniqueness_of は「既存レコード」が必要なため create で永続化する
      subject { create(:aroma_tag) }

      # ignoring_case_sensitivity … 名前が日本語で大文字・小文字を入れ替えられないため、その確認を飛ばす
      it { is_expected.to validate_uniqueness_of(:name).scoped_to(:category).ignoring_case_sensitivity }
    end

    it "category は 吟醸香・原料香・熟成香 の3区分の enum" do
      is_expected.to define_enum_for(:category).with_values(ginjo: 0, ingredient: 1, aged: 2)
    end

    it "同じ区分に同じ名前を作れない（DB の unique index）" do
      is_expected.to have_db_index([ :category, :name ]).unique
    end
  end

  describe "アソシエーション" do
    it { is_expected.to have_many(:aroma_profile_aroma_tags).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:aroma_profiles).through(:aroma_profile_aroma_tags) }
  end

  describe ".ordered" do
    it "区分ごと・表示順に並ぶ" do
      aged_first = create(:aroma_tag, category: :aged, position: 1)
      ginjo_second = create(:aroma_tag, category: :ginjo, position: 2)
      ginjo_first = create(:aroma_tag, category: :ginjo, position: 1)

      expect(AromaTag.ordered).to eq [ ginjo_first, ginjo_second, aged_first ]
    end
  end

  # 表示順の unique 制約（チェックはトランザクションの最後）
  # テストは1件ごとにトランザクションの中で動き、最後に確定しない。
  # そのままでは遅延チェックが走らないので、SET CONSTRAINTS ALL IMMEDIATE で「今すぐチェック」させる
  describe "表示順の重複" do
    # 遅らせていた制約のチェックを、その場で実行させる
    # @return [void]
    def check_constraints_now
      ActiveRecord::Base.connection.execute("SET CONSTRAINTS ALL IMMEDIATE")
    end

    it "並べ直しの途中で番号が重なっても、最後にそろっていればエラーにならない" do
      first_tag = create(:aroma_tag, category: :ginjo, position: 1)
      second_tag = create(:aroma_tag, category: :ginjo, position: 2)

      first_tag.update!(position: 2)  # この時点では2つとも 2（一時的に重複）
      second_tag.update!(position: 1) # 入れ替え完了

      expect { check_constraints_now }.not_to raise_error
    end

    it "最後まで番号が重なったままだとエラーになる" do
      create(:aroma_tag, category: :ginjo, position: 1)
      create(:aroma_tag, category: :ginjo, position: 2).update!(position: 1)

      expect { check_constraints_now }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "区分が違えば同じ番号でもエラーにならない" do
      create(:aroma_tag, category: :ginjo, position: 1)
      create(:aroma_tag, category: :aged, position: 1)

      expect { check_constraints_now }.not_to raise_error
    end
  end

  # dependent: :restrict_with_error の設定だけでなく、実際に削除が止まることを確かめる
  describe "削除" do
    it "記録で選ばれているタグは削除できない" do
      aroma_tag = create(:aroma_tag)
      create(:aroma_profile, aroma_tags: [ aroma_tag ])

      expect(aroma_tag.destroy).to be false
      expect(AromaTag.exists?(aroma_tag.id)).to be true
    end
  end
end
