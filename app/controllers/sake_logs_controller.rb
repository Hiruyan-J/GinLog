class SakeLogsController < ApplicationController
  def index
    @sake_logs = SakeLog.includes(:sake)
  end

  def new
    @sakes = Sake.all
    @sake_log = SakeLog.new
  end

  def create
    @product_name = params[:sake_log][:product_name].strip

    SakeLog.transaction do
      @sake = Sake.find_or_create_by!(product_name: @product_name)
      @sake_log = current_user.sake_logs.build(sake_log_params)
      @sake_log.sake = @sake
      @sake_log.save!
    rescue ActiveRecord::RecordInvalid => exception
      flash.now[:error] = t('defaults.flash_message.not_created', sake_log: SakeLog.model_name.human)
      render :new, status: :unprocessable_entity
      return
    end

    redirect_to sake_logs_path, success: t('defaults.flash_message.created', item: SakeLog.model_name.human)
  end

  private
  def sake_log_params
    params.require(:sake_log).permit(:rating, :aroma_strength, :taste_strength, :review)
  end
end
