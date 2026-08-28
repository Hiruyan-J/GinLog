require 'rails_helper'

# == Schema Information
#
# Table name: label_extraction_logs(AIラベル読み取りの実行履歴。1日あたりの回数制限に使用)
#
#  id                                                             :bigint           not null, primary key
#  executed_on(実行日（日本時間）。1日あたりの回数制限の集計キー) :date             not null
#  created_at                                                     :datetime         not null
#  updated_at                                                     :datetime         not null
#  user_id                                                        :bigint           not null
#
# Indexes
#
#  index_label_extraction_logs_on_user_id_and_executed_on  (user_id,executed_on)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe LabelExtractionLog, type: :model do
  let(:user) { create(:user) }

  describe "executed_on の自動セット" do
    it "指定しなければ日本時間の今日が入る" do
      log = described_class.create!(user: user)

      expect(log.executed_on).to eq(Date.current)
    end
  end

  describe ".remaining_for" do
    it "実行していなければ上限回数をそのまま返す" do
      expect(described_class.remaining_for(user)).to eq(described_class::DAILY_LIMIT)
    end

    it "本日の実行分だけ残り回数が減る" do
      create_list(:label_extraction_log, 3, user: user)

      expect(described_class.remaining_for(user)).to eq(described_class::DAILY_LIMIT - 3)
    end

    it "前日の実行分は数えない" do
      create_list(:label_extraction_log, described_class::DAILY_LIMIT,
                    user: user, executed_on: Date.current - 1)

      expect(described_class.remaining_for(user)).to eq(described_class::DAILY_LIMIT)
    end

    it "他のユーザーの実行分は数えない" do
      other_user = create(:user)
      create_list(:label_extraction_log, 5, user: other_user)

      expect(described_class.remaining_for(user)).to eq(described_class::DAILY_LIMIT)
    end

    it "上限回数以上実行していても戻り値の最小値は0" do
      create_list(:label_extraction_log, described_class::DAILY_LIMIT + 1, user: user)

      expect(described_class.remaining_for(user)).to eq(0)
    end
  end

  describe ".limit_reached?" do
    it "上限未満なら false を返す" do
      create_list(:label_extraction_log, described_class::DAILY_LIMIT - 1, user: user)

      expect(described_class.limit_reached?(user)).to be(false)
    end

    it "上限に達したら true を返す" do
      create_list(:label_extraction_log, described_class::DAILY_LIMIT, user: user)

      expect(described_class.limit_reached?(user)).to be(true)
    end
  end
end
