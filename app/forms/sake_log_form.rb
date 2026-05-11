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
  # 銘柄手入力モード用の属性
  attribute :manual_brand_name, :string
  attribute :manual_brewery_name, :string
  attribute :brewery_id, :integer           # オートコンプリートで選択した蔵元ID
  attribute :area_id, :integer              # 都道府県ID (蔵元手入力時)

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
  # 銘柄手入力モード時のバリデーション
  validates :manual_brand_name, presence: true, length: { maximum: Brand::NAME_MAX_LENGTH }, if: :manual_brand_mode?
  validates :brewery_id, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :area_id, presence: { message: "を選択してください" },
                      numericality: { only_integer: true, greater_than: 0, allow_nil: true },
                      if: :manual_brewery_mode?
  validates :manual_brewery_name, presence: true, length: { maximum: Brewery::NAME_MAX_LENGTH }, if: :manual_brewery_mode?

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
      # 銘柄手入力モード時は Brand/Brewery を先に作成
      resolve_brand_id! if manual_brand_mode?

      # sake_idがある場合は既存レコードを使用、なければ検索・作成
      sake = find_or_initialize_sake

      # 複合ユニークインデックス違反時は既存レコードを再検索
      begin
        sake.save!
      rescue ActiveRecord::RecordNotUnique
        sake = Sake.find_by!(
          product_name: product_name.strip,
          brand_id: brand_id
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
    rescue ActiveRecord::RecordNotFound
      errors.add(:base, "指定された日本酒が見つかりませんでした")
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

  # 銘柄名（通常モード: Brand.name、手入力モード: manual_brand_name）
  # @return [String, nil] 銘柄名（例: 「赤武」）
  def brand_display_name
    return Brand.find_by(id: brand_id)&.name if brand_id.present?

    manual_brand_name
  end

  # 蔵元名（通常モード: Brewery.name、蔵元選択時: Brewery.name、蔵元手入力時: manual_brewery_name）
  # @return [String, nil] 蔵元名（例: 「赤武酒造」）
  def brewery_display_name
    if brand_id.present?
      brand = Brand.includes(:brewery).find_by(id: brand_id)
      return brand&.brewery&.name
    end

    if brewery_id.present?
      return Brewery.find_by(id: brewery_id)&.name
    end

    manual_brewery_name
  end

  # 都道府県名
  # （通常モード: Area.name、手入力モード: 選択した Area.name）
  # @return [String, nil] 都道府県名（例: 「岩手県」）
  def area_display_name
    if brand_id.present?
      brand = Brand.includes(brewery: :area).find_by(id: brand_id)
      return brand&.brewery&.area&.name
    end

    if brewery_id.present?
      brewery = Brewery.includes(:area).find_by(id: brewery_id)
      return brewery&.area&.name
    end

    return Area.find_by(id: area_id)&.name if area_id.present?

    nil
  end

  def manual_brand_mode?
    brand_id.blank?
  end

  def manual_brewery_mode?
    manual_brand_mode? && brewery_id.blank?
  end

  # 銘柄が確定済みか(商品名入力欄の活性判定に使用)
  # 通常モードでbrand_id が present、または手入力モードで manual_brand_name が入力済み⇒true
  # @return [Boolean]
  def brand_committed?
    brand_id.present? || manual_brand_name.present?
  end

  # 蔵元手入力モードかつユーザーが既に入力を開始しているか
  # 都道府県selectの初期表示判定に使用
  # 新規フォーム(全て空)ではfalseを返し、selectが表示されないようにする
  # @return [Boolean]
  def manual_brewery_input_started?
    manual_brewery_mode? && manual_brand_name.present?
  end

  # 都道府県の選択肢
  # @return [Array<Array<String, Integer>>] [["北海道", 1], ["青森県", 2], ...]
  def area_options
    Area.order(:id).pluck(:name, :id)
  end

  private

  # 銘柄手入力モード時に Brand(と必要なら Brewery)を作成し、brand_id をセットする
  # @return [void]
  def resolve_brand_id!
    brewery = find_or_create_brewery!
    brand = find_or_create_brand!(brewery)
    self.brand_id = brand.id
  end

  # 蔵元の検索または作成
  # brewery_id があれば既存 Brewery を使用
  # なければ名前+エリアで検索、なければ新規作成。
  # @return [Brewery] 既存または新規の Brewery レコード
  def find_or_create_brewery!
    if brewery_id.present?
      Brewery.find(brewery_id)
    else
      Brewery.find_or_create_by!(
        name: manual_brewery_name.strip,
        area_id: area_id
      )
    end
  end

  # 銘柄の検索または作成
  # 同名+同蔵元の Brand が既にあれば再利用、なければ新規作成
  # @param brewery [Brewery] 紐づける蔵元
  # @return [Brand] 既存または新規の Brand レコード
  def find_or_create_brand!(brewery)
    Brand.find_or_create_by!(
      name: manual_brand_name.strip,
      brewery_id: brewery.id
    )
  end

  # Sakeの検索または初期化(brand_id, sake_idを考慮)
  # @return [Sake] 既存または、新規のSakeオブジェクト
  def find_or_initialize_sake
    if sake_id.present?
      # 既存のSakeレコードを使用(オートコンプリートで選択した場合)
      Sake.find_by!(id: sake_id, brand_id: brand_id)
    else
      # 新規のSakeレコードを検索または作成
      Sake.find_or_initialize_by(
        product_name: product_name.strip,
        brand_id: brand_id
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
