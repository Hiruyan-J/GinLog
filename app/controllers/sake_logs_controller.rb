class SakeLogsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[show]

  def index
    @sake_logs = current_user.sake_logs.includes(:sake).order(created_at: :desc)
  end

  def show
    @sake_log = SakeLog.includes(:user, sake: { brand: { brewery: :area } })
                        .with_attached_images
                        .find(params[:id])
  end

  def new
    @form = SakeLogForm.new(user: current_user)
  end

  def create
    @form = SakeLogForm.new(sake_log_form_params, user: current_user)

    if @form.save
      redirect_to sake_log_path(@form.sake_log), success: t("defaults.flash_message.created", item: SakeLog.model_name.human)
    else
      flash.now[:error] = t("defaults.flash_message.not_created", item: SakeLog.model_name.human) # TODO: ログ出力
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    set_sake_log
    @form = SakeLogForm.new(user: current_user, sake_log: @sake_log)
  end

  def update
    set_sake_log
    @form = SakeLogForm.new(sake_log_form_params, user: current_user, sake_log: @sake_log)

    if @form.save
      redirect_to sake_log_path(@form.sake_log), success: t("defaults.flash_message.updated", item: SakeLog.model_name.human)
    else
      flash.now[:error] = t("defaults.flash_message.not_updated", item: SakeLog.model_name.human) # TODO: ログ出力
      render :edit, status: :unprocessable_entity
    end
  end

  # 削除元によって応答を変える
  #   一覧（タイムライン）から削除 → Turbo Stream でそのカードだけ消す（ページ遷移しない）
  #   記録詳細から削除            → マイログ一覧へ戻る
  def destroy
    set_sake_log

    unless @sake_log.destroy
      redirect_back fallback_location: sake_logs_path,
                    error: t("defaults.flash_message.not_deleted", item: SakeLog.model_name.human),
                    status: :see_other
      return
    end

    if delete_from_list?
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

  # 一覧画面からの削除かどうか（一覧ではページ遷移せず、そのカードだけを消す）
  #   一覧のカードにある削除リンクだけが from=list を付けて送ってくる。
  def delete_from_list?
    params[:from] == "list"
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
