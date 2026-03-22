class SakeLogForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  # フォームの属性
  # Sake attributes
  attribute :product_name, :string
  attribute :brand_id, :integer
  attribute :sake_id, :integer
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
  validates :brand_id, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :sake_id, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
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
  # @param attributes [Hash] フォームの属性
  # @param user [User] ログイン中のユーザー
  # @param sake_log [SakeLog, nil] 編集時の既存SakeLog（新規作成時はnil）
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
          product_name: @sake_log.sake.product_name,
          brand_id: @sake_log.sake.brand_id,
          sake_id: @sake_log.sake.id
        }.merge(attributes)
      end
      super(attributes)
  end

  # 保存処理
  # @return [Boolean] 保存成功なら true
  def save
    return false if invalid?

    SakeLog.transaction do
      # sake_idがある場合は既存レコードを使用、なければ検索・作成
      sake = find_or_initialize_sake

      # 複合ユニークインデックス違反時は既存レコードを再検索
      begin
        sake.save!
      rescue ActiveRecord::RecordNotUnique
        sake = Sake.find_by!(
          product_name: product_name.strip,
          brand_id: brand_id.presence
        )
      end

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

  # 銘柄名(オートコンプリート入力欄の初期表示用)
  # @return [string, nil] 銘柄名（例: 「赤武」）
  def brand_display_name
    return nil if brand_id.blank?

    Brand.find_by(id: brand_id)&.name
  end

  # 蔵元名(蔵元表示エリアの初期表示用)
  # @return [String, nil] 「赤武酒造（岩手県）」形式の蔵元名
  def brewery_display_name
    return nil if brand_id.blank?

    brand = Brand.includes(brewery: :area).find_by(id: brand_id)
    return nil unless brand

    "#{brand.brewery.name}（#{brand.brewery.area.name}）"
  end

  private

  # Sakeの検索または初期化(brand_id, sake_idを考慮)
  # @return [Sake] 既存または、新規のSakeオブジェクト
  def find_or_initialize_sake
    if sake_id.present?
      # 既存のSakeレコードを使用(オートコンプリートで選択した場合)
      Sake.find(sake_id)
    else
      # 新規のSakeレコードを検索または作成
      Sake.find_or_initialize_by(
        product_name: product_name.strip,
        brand_id: brand_id.presence
      )
    end
  end

  def sake_log_attributes
    {
      rating: rating,
      aroma_strength: aroma_strength,
      taste_strength: taste_strength,
      review: review
    }
  end

  # モデルのバリデーションエラーをFormObjectに転記する
  # @param record [ActiveRecord::Base] エラーが発生したレコード（SakeまたはSakeLog）
  # @return [void]
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
