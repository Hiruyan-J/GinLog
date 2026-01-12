class SakeLogForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Sake attributes  # TODO: sake_idも必要?
  attribute :product_name, :string

  # SakeLog attributes
  attribute :rating, :integer, default: SakeLog::RATING_MIN  # TODO: デフォルト値は不要?
  attribute :aroma_strength, :float
  attribute :taste_strength, :float
  attribute :review, :text


  validates :product_name, presence: true # TODO: length制限も必要?

  # SakeLog attributesバリデーション
  # TODO: SakeLogモデルの記述を削除?その場合、定数の宣言場所も再考
  validates :rating, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: SakeLog::RATING_MIN, less_than_or_equal_to: SakeLog::RATING_MAX }
  validates :taste_strength, presence: true, numericality: { greater_than_or_equal_to: SakeLog::TASTE_STRENGTH_MIN, less_than_or_equal_to: SakeLog::TASTE_STRENGTH_MAX }
  validates :aroma_strength, presence: true, numericality: { greater_than_or_equal_to: SakeLog::AROMA_STRENGTH_MIN, less_than_or_equal_to: SakeLog::AROMA_STRENGTH_MAX }
  validates :review, length: { maximum: 65_535 }  # TODO: 文字数制限を定数化?

  attr_accessor :user, :sake_log, :sake

  def initialize(attributes = {}, user: , sake_log: nil)
    @user = user
    @sake_log = sake_log || user.sake_logs.build
    @sake = @sake_log.sake || Sake.new
    super(attributes) # TODO: attributesの中身を確認

    # 編集時はモデルの値をフォームの属性にセット
    self.product_name ||= @sake.product_name # TODO: selfの内容を確認
    self.rating ||= @sake_log.rating
    self.aroma_strength ||= @sake_log.aroma_strength
    self.taste_strength ||= @sake_log.taste_strength
    self.review ||= @sake_log.review
  end

  def save
    return false if invalid?

    ActiveRecord::Base.transaction do
      # 銘柄を特定/作成
      self.sake = Sake.find_or_initialize_by(product_name: product_name.strip)
      sake.save!

      # 記録を保存
      sake_log.assign_attributes(
        user: user,
        sake: sake,
        rating: rating,
        aroma_strength: aroma_strength,
        taste_strength: taste_strength,
        review: review
      )
      sake_log.save!
      true
    end
  rescue ActiveRecord::RecordInvalid => exception
    false
  end

  # form_withが PATCH か POST かを判別
  def persisted?
    sake_log.persisted?  # sake_logがDBに存在するかどうか
  end

end