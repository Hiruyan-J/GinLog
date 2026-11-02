require 'rails_helper'

# == Schema Information
#
# Table name: likes
#
#  id          :bigint           not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  sake_log_id :bigint           not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_likes_on_sake_log_id              (sake_log_id)
#  index_likes_on_user_id                  (user_id)
#  index_likes_on_user_id_and_sake_log_id  (user_id,sake_log_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (sake_log_id => sake_logs.id)
#  fk_rails_...  (user_id => users.id)
#
RSpec.describe Like, type: :model do
  describe "バリデーション" do
    subject { build(:like) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_uniqueness_of(:user_id).scoped_to(:sake_log_id) }
  end

  describe "二重いいねの防止" do
    let(:like) { create(:like) }

    it "バリデーションを飛ばしても DB のユニーク制約で防ぐ" do
      duplicate = build(:like, user: like.user, sake_log: like.sake_log)

      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "アソシエーション" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:sake_log) }
  end
end
