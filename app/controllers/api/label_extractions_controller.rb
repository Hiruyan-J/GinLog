# AIラベル読み取りAPIコントローラ
class Api::LabelExtractionsController < ApplicationController
  # AI読み取り1回で送信できる画像の合計サイズ
  #
  # Gemini APIのファイルサイズ上限ではなく、アプリケーションサーバーの
  # メモリ使用量を抑えるための制限。
  #
  # Geminiへの送信時には、画像の生バイトに加えてBase64文字列やJSON本文が
  # 一時的にメモリ上へ保持される。実測では画像サイズの約4倍のメモリを使用するため、
  # 512MB環境で複数リクエストを並行処理しても余裕を残せるよう15MBに制限する。
  #
  # SakeLog::IMAGE_MAX_SIZEは「保存可能な画像1枚のサイズ」、
  # この定数は「AI読み取り1回で扱う画像全体のサイズ」を制限するもの。
  # 目的が異なるため、SakeLog::IMAGE_MAX_SIZEとは連動させない。
  #
  # 通常はブラウザ側で画像を縮小するため、この上限に達することは想定していない。
  # HEICなどをブラウザ側で縮小できず、元ファイルをそのまま送信する場合に、
  # サーバーの過剰なメモリ使用を防ぐための安全策として機能する。
  EXTRACTION_IMAGES_MAX_SIZE = 15.megabytes


  # POST /api/label_extraction
  # 表(+裏)ラベル画像を受け取り、抽出結果とマスタ照合結果をJSONで返す
  # @return [void]
  def create
    if LabelExtractionLog.limit_reached?(current_user)
      render json: { error: "本日のAI読み取りの利用上限（#{LabelExtractionLog::DAILY_LIMIT}回）に達しました。明日また利用できます" },
             status: :too_many_requests
      return
    end

    front_image = build_image(params[:front_label_image])
    if front_image.nil?
      render json: { error: "表ラベルの写真を選択してください（JPEG・PNG・WebP・HEIC・HEIF形式、10MB以下）" },
             status: :unprocessable_entity
      return
    end

    back_image = build_image(params[:back_label_image])
    if images_too_large?(front_image, back_image)
      render json: { error: "写真のサイズが大きすぎます。別の写真を選ぶか、小さいサイズでお試しください" },
             status: :unprocessable_entity
      return
    end

    # 回数はAPI呼び出しの前に記録する（呼び出しが失敗しても1回と数える）
    LabelExtractionLog.create!(user: current_user)

    result = LabelExtraction::Extractor.new(
      front_image: front_image,
      back_image: back_image
    ).call

    render json: result.merge(remaining_count: LabelExtractionLog.remaining_for(current_user))
  rescue LabelExtraction::GeminiClient::ApiError => e
    Rails.logger.error("AIラベル読み取りに失敗しました: #{e.message}")
    render json: { error: "読み取りに失敗しました。時間をおいて再度お試しください" }, status: :bad_gateway
  end

  private

  # 送信する画像の合計サイズが上限を超えているか
  # @param images [Array<Hash, nil>] build_image の戻り値（nil は無視する）
  # @return [Boolean] 上限を超えていれば true
  def images_too_large?(*images)
    images.compact.sum { |image| image[:data].bytesize } > EXTRACTION_IMAGES_MAX_SIZE
  end

  # アップロードされた画像を Extractor へ渡す Hash に変換する
  # 対応形式以外・サイズ超過・未指定は nil を返す
  #
  # 形式はブラウザの申告値（content_type）ではなく実際のバイトから判定する。
  # SakeLog の検証（detected_content_type）と同じ判定に揃えることで、
  # 拡張子を偽装したファイルを Gemini に送って失敗し、
  # 1日の利用回数の内の1回分を無駄にするのを防ぐ。
  # Marcel は読み取り位置を戻すので、このあと read してもバイトはすべて取れる。
  #
  # @param uploaded_file [ActionDispatch::Http::UploadedFile, nil] アップロードされたファイル
  # @return [Hash, nil] { mime_type: String, data: String(バイナリ) } または nil
  def build_image(uploaded_file)
    return nil if uploaded_file.blank?

    content_type = Marcel::MimeType.for(uploaded_file)
    return nil unless SakeLog::IMAGE_CONTENT_TYPES.include?(content_type)
    return nil if uploaded_file.size > SakeLog::IMAGE_MAX_SIZE

    { mime_type: content_type, data: uploaded_file.read }
  end
end
