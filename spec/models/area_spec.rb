require 'rails_helper'

# == Schema Information
#
# Table name: areas
#
#  id          :bigint           not null, primary key
#  name        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  sakenowa_id :integer          not null
#
# Indexes
#
#  index_areas_on_sakenowa_id  (sakenowa_id) UNIQUE
#
RSpec.describe Area, type: :model do
  describe "バリデーション" do
    subject { build(:area) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(Area::NAME_MAX_LENGTH) }
  end

  describe "アソシエーション" do
    it { is_expected.to have_many(:breweries).dependent(:restrict_with_exception) }
  end

  describe ".prefectures" do
    it "「その他」を除き、さけのわの ID 順（北から順）に返す" do
      # 作成順（id 順）とは逆になるよう、新潟県を先に作る
      niigata = create(:area, name: "新潟県", sakenowa_id: 15)
      hokkaido = create(:area, name: "北海道", sakenowa_id: 1)
      create(:area, name: "その他", sakenowa_id: Area::OTHER_SAKENOWA_ID)

      expect(Area.prefectures).to eq [ hokkaido, niigata ]
    end
  end
end
