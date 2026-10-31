require "rails_helper"

RSpec.describe PreferenceAnalysesHelper, type: :helper do
  describe "PREFECTURE_TILE_POSITIONS" do
    it "47都道府県すべてに、重ならない位置が決まっている" do
      positions = PreferenceAnalysesHelper::PREFECTURE_TILE_POSITIONS
      # 各タイルが使うマスを [行, 列] の形ですべて並べる
      cells = positions.values.flat_map do |row, column, row_span, column_span|
        (row...(row + row_span)).to_a.product((column...(column + column_span)).to_a)
      end

      expect(positions.size).to eq 47
      expect(cells.uniq.size).to eq cells.size
    end
  end

  describe "#okinawa_frame_style" do
    # @param position [Array<Integer>] [行, 列, 縦のマス数, 横のマス数]
    # @return [Array<Array<Integer>>] 使うマスの [行, 列] の一覧
    def cells_of(position)
      row, column, row_span, column_span = position
      (row...(row + row_span)).to_a.product((column...(column + column_span)).to_a)
    end

    it "枠の位置と大きさを返す" do
      expect(helper.okinawa_frame_style).to eq "grid-row: 9 / span 4; grid-column: 1 / span 3;"
    end

    it "枠は沖縄のタイルを囲み、ほかのタイルとは重ならない" do
      positions = PreferenceAnalysesHelper::PREFECTURE_TILE_POSITIONS
      frame_cells = cells_of(PreferenceAnalysesHelper::OKINAWA_FRAME_POSITION)

      expect(frame_cells).to include(*cells_of(positions.fetch("沖縄県")))
      expect(frame_cells & positions.except("沖縄県").values.flat_map { |position| cells_of(position) }).to be_empty
    end
  end

  describe "#prefecture_tile_style" do
    it "表にある都道府県なら grid の位置と大きさを返す" do
      expect(helper.prefecture_tile_style(build(:area, name: "新潟県"))).to eq "grid-row: 11 / span 2; grid-column: 21 / span 3;"
    end

    it "表にない名前なら nil を返す" do
      expect(helper.prefecture_tile_style(build(:area, name: "その他"))).to be_nil
    end
  end

  describe "#prefecture_tile_label" do
    it "どの都道府県も、タイルの横のマス数に収まる文字数になる" do
      PreferenceAnalysesHelper::PREFECTURE_TILE_POSITIONS.each do |name, (_row, _column, _row_span, column_span)|
        expect(helper.prefecture_tile_label(build(:area, name: name)).length).to be <= column_span
      end
    end

    it "末尾の 都・府・県 を除いた名前を返す" do
      expect(helper.prefecture_tile_label(build(:area, name: "新潟県"))).to eq "新潟"
      expect(helper.prefecture_tile_label(build(:area, name: "東京都"))).to eq "東京"
      expect(helper.prefecture_tile_label(build(:area, name: "京都府"))).to eq "京都"
      expect(helper.prefecture_tile_label(build(:area, name: "北海道"))).to eq "北海道"
      expect(helper.prefecture_tile_label(build(:area, name: "和歌山県"))).to eq "和歌山"
    end
  end

  describe "#prefecture_tile_class" do
    let(:levels) { PreferenceAnalysesHelper::RATING_LEVELS }

    # @param average [Float] 平均好み度
    # @return [PreferenceAnalysis::Stat]
    def stat(average)
      PreferenceAnalysis::Stat.new(average: average, count: 1)
    end

    it "平均好み度を整数部分で5段階に分け、5.0 は一番上の段階にする" do
      expect(helper.prefecture_tile_class(stat(0.0), false)).to eq levels[0][:tile_class]
      expect(helper.prefecture_tile_class(stat(0.9), false)).to eq levels[0][:tile_class]
      expect(helper.prefecture_tile_class(stat(1.0), false)).to eq levels[1][:tile_class]
      expect(helper.prefecture_tile_class(stat(3.9), false)).to eq levels[3][:tile_class]
      expect(helper.prefecture_tile_class(stat(4.0), false)).to eq levels[4][:tile_class]
      expect(helper.prefecture_tile_class(stat(5.0), false)).to eq levels[4][:tile_class]
    end

    it "記録がなければ灰色にする" do
      expect(helper.prefecture_tile_class(nil, false)).to eq PreferenceAnalysesHelper::NO_RECORD_TILE_CLASS
    end

    it "一番好きな都道府県なら強調のクラスを足す" do
      expect(helper.prefecture_tile_class(stat(4.5), true)).to include PreferenceAnalysesHelper::BEST_TILE_CLASS
    end
  end

  describe "#prefecture_tile_title" do
    let(:area) { build(:area, name: "新潟県") }

    it "記録があれば平均（小数第1位まで）と件数を返す" do
      expect(helper.prefecture_tile_title(area, PreferenceAnalysis::Stat.new(average: 4.25, count: 3))).to eq "新潟県：平均 4.3（3件）"
    end

    it "記録がなければ未記録と返す" do
      expect(helper.prefecture_tile_title(area, nil)).to eq "新潟県：未記録"
    end
  end
end
