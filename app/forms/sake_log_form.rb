class SakeLogForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  # フォームの属性
  # Sake attributes
  attribute :product_name, :string
  # SakeLog attributes
  attribute :rating, :integer
  attribute :aroma_strength, :float
  attribute :taste_strength, :float
  attribute :review, :string

  # 関連オブジェクト (ゲッターのみ)
  attr_reader :sake_log, :user


  # バリデーション
  # Sake attributesバリデーション
  validates :product_name, presence: true, length: { maximum: Sake::PRODUCT_NAME_MAX_LENGTH }
  # SakeLog attributesバリデーション
  validates :rating, presence: true,
                      numericality: { only_integer: true,
                                      greater_than_or_equal_to: SakeLog::RATING_MIN,
                                      less_than_or_equal_to: SakeLog::RATING_MAX,
                                      allow_nil: true } # nilはpresenceで弾き、numericalityはnil以外のときのみチェック
  validates :taste_strength, presence: true,
                      numericality: { greater_than_or_equal_to: SakeLog::TASTE_STRENGTH_MIN,
                                      less_than_or_equal_to: SakeLog::TASTE_STRENGTH_MAX }
  validates :aroma_strength, presence: true,
                              numericality: { greater_than_or_equal_to: SakeLog::AROMA_STRENGTH_MIN,
                                              less_than_or_equal_to: SakeLog::AROMA_STRENGTH_MAX }
  validates :review, length: { maximum: SakeLog::REVIEW_MAX_LENGTH }, allow_blank: true

  # コンストラクタ
  def initialize(attributes = {}, user:, sake_log: nil)
      @user = user
      @sake_log = sake_log

      if @sake_log
        # 編集時: 既存データから属性をセット
        attributes = {
          rating: @sake_log.rating,
          aroma_strength: @sake_log.aroma_strength,
          taste_strength: @sake_log.taste_strength,
          review: @sake_log.review,
          product_name: @sake_log.sake.product_name
        }.merge(attributes)
      end
      super(attributes)
  end

  # 保存処理
  def save
    return false if invalid?

    SakeLog.transaction do
      # Sakeの検索または作成
      sake = Sake.find_or_initialize_by(product_name: product_name.strip)
      sake.save!

      # SakeLogの作成または更新
      if @sake_log
        # 更新
        @sake_log.assign_attributes(sake_log_attributes)
        @sake_log.sake = sake
        @sake_log.save!
      else
        # 新規作成
        @sake_log = @user.sake_logs.build(sake_log_attributes)
        @sake_log.sake = sake
        @sake_log.save!
      end

      true
    rescue ActiveRecord::RecordInvalid => e
      # モデルのエラーをFormObjectに転記
      copy_errors_from_record(e.record)
      false
    end
  end

  # from_withとの連携用メソッド
  # form_withが PATCH か POST かを判別
  def persisted?
    @sake_log&.persisted? # sake_logがDBに存在するかどうか
  end

  def model_name
    SakeLog.model_name
  end

  private

  def sake_log_attributes
    {
      rating: rating,
      aroma_strength: aroma_strength,
      taste_strength: taste_strength,
      review: review
    }
  end

  def copy_errors_from_record(record)
    record.errors.each do |error|
      # Sakeのエラーの場合、product_nameに割り当て
      if record.is_a?(Sake) && error.attribute == :product_name
        self.errors.add(:product_name, error.message)
      elsif record.is_a?(SakeLog)
        self.errors.add(error.attribute, error.message)
      end
    end
  end
end
