class SakeLogsController < ApplicationController
  # 一覧からの削除（＝ページ遷移せず、そのカードだけを消す）とみなす遷移元
  LIST_ORIGINS = %w[timeline mylog sake].freeze

  skip_before_action :authenticate_user!, only: %i[show]

  # マイログ一覧（自分の記録の一覧）
  #   1ページ 10件（config/initializers/kaminari_config.rb の default_per_page）で、
  #   2ページ目以降は末尾の Turbo Frame から読み込まれる（無限スクロール）
  def index
    @sake_logs = current_user.sake_logs
                             .includes(sake: { brand: { brewery: :area } })
                             .with_attached_images
                             .order(created_at: :desc, id: :desc)
                             .page(params[:page])

    render :page if turbo_frame_request?
  end

  def show
    @sake_log = SakeLog.includes(:user, sake: { brand: { brewery: :area } })
                        .with_attached_images
                        .find(params[:id])
    # どの画面から来たか（"timeline" / "mylog" / "sake"）。無い場合は nil 。
    #   値の判定はビュー側の sake_log_back_link に任せる（知らない値が来ても既定の戻り先になる）
    @origin = params[:from]
  end

  def new
    @sake_log_form = SakeLogForm.new(user: current_user)
  end

  def create
    @sake_log_form = SakeLogForm.new(sake_log_form_params, user: current_user)

    if @sake_log_form.save
      redirect_to sake_log_path(@sake_log_form.sake_log), success: t("defaults.flash_message.created", item: SakeLog.model_name.human)
    else
      flash.now[:error] = t("defaults.flash_message.not_created", item: SakeLog.model_name.human) # TODO: ログ出力
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    set_sake_log
    @sake_log_form = SakeLogForm.new(user: current_user, sake_log: @sake_log)
  end

  def update
    set_sake_log
    @sake_log_form = SakeLogForm.new(sake_log_form_params, user: current_user, sake_log: @sake_log)

    if @sake_log_form.save
      redirect_to sake_log_path(@sake_log_form.sake_log), success: t("defaults.flash_message.updated", item: SakeLog.model_name.human)
    else
      flash.now[:error] = t("defaults.flash_message.not_updated", item: SakeLog.model_name.human) # TODO: ログ出力
      render :edit, status: :unprocessable_entity
    end
  end

  # 削除元によって応答を変える
  #   一覧（タイムライン / マイログ一覧 / 日本酒詳細）から削除 → Turbo Stream でそのカードだけ消す（ページ遷移しない）
  #   記録詳細から削除                          → マイログ一覧へ戻る
  def destroy
    set_sake_log

    sake = @sake_log.sake

    unless @sake_log.destroy
      redirect_back fallback_location: sake_logs_path,
                    error: t("defaults.flash_message.not_deleted", item: SakeLog.model_name.human),
                    status: :see_other
      return
    end

    if stay_on_list?(sake)
      flash.now[:success] = t("defaults.flash_message.deleted", item: SakeLog.model_name.human)
      render turbo_stream: [
        turbo_stream.remove(@sake_log),
        turbo_stream.replace("flash_messages", partial: "shared/flash_message")
      ]
    else
      redirect_to sake_logs_path,
                  success: t("defaults.flash_message.deleted", item: SakeLog.model_name.human),
                  status: :see_other
    end
  end

  private

  def set_sake_log
    @sake_log = current_user.sake_logs.find(params[:id])
  end

  # 削除した後も、表示中の一覧ページがそのまま残るか
  #   残るなら Turbo Stream でカードだけ消す。残らないならリダイレクトする。
  #   一覧のカードにある削除リンクだけが遷移元（from）を付けて送ってくる。
  #
  #   日本酒詳細だけは特別で、最後の記録を消すと SakeAggregationJob が
  #   その日本酒自体を削除する。カードだけ消して留まると、
  #   存在しないページを表示し続けてしまうため、リダイレクトさせる。
  #
  # @param sake [Sake] 削除した記録が紐づいていた日本酒
  # @return [Boolean] 一覧に留まってよいなら true
  def stay_on_list?(sake)
    return false unless LIST_ORIGINS.include?(params[:from])

    # 日本酒詳細のときだけ、その日本酒に記録が残っているかを確認する
    params[:from] != "sake" || sake.sake_logs.exists?
  end

  def sake_log_form_params
    params.require(:sake_log).permit(
      :rating, :aroma_strength, :taste_strength, :review,
      :product_name, :brand_id, :sake_id,
      :manual_brand_name, :manual_brewery_name, :brewery_id, :area_id,
      :front_label_image, :back_label_image, :sub_image1, :sub_image2,
      :remove_front_label_image, :remove_back_label_image,
      :remove_sub_image1, :remove_sub_image2
    )
  end
end
