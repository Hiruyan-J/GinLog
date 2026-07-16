require 'rails_helper'

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
end
