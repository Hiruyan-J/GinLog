class SakeLogsController < ApplicationController

  def index
    @sake_logs = current_user.sake_logs.includes(:sake).order(created_at: :desc)
  end

  def new
    @form = SakeLogForm.new(user: current_user)
  end

  def create
    @form = SakeLogForm.new(sake_log_form_params, user: current_user)

    if @form.save
      redirect_to sake_logs_path, success: t("defaults.flash_message.created", items: SakeLog.model_name.human)
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
      redirect_to sake_logs_path, success: t("defaults.flash_message.updated", item: SakeLog.model_name.human)
    else
      flash.now[:error] = t("defaults.flash_message.not_updated", item: SakeLog.model_name.human) # TODO: ログ出力
      render :edit, status: :unprocessable_entity
    end
  end

def destroy
  set_sake_log
  if @sake_log.destroy
    redirect_to sake_logs_path, success: t("defaults.flash_message.deleted", item: SakeLog.model_name.human), status: :see_other
  else
    redirect_back fallback_location: sake_logs_path, error: t("defaults.flash_message.not_deleted", item: SakeLog.model_name.human), status: :see_other
  end
end

  private

  def set_sake_log
    @sake_log = current_user.sake_logs.find(params[:id])
  end

  def sake_log_params
    params.require(:sake_log).permit(:rating, :aroma_strength, :taste_strength, :review, :product_name)
  end
end
