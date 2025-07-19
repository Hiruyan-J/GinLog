class SakeLogsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]

  def index
    @sake_logs = SakeLog.includes([ :user, :sake ]).order(created_at: :desc)
  end

  def new
    @sakes = Sake.all
    @sake_log = SakeLog.new
    @sake = @sake_log.build_sake
  end

  def create
    @product_name = params[:sake_log][:sake_attributes][:product_name].strip

    SakeLog.transaction do
      @sake = Sake.find_or_create_by!(product_name: @product_name)
      @sake_log = current_user.sake_logs.build(sake_log_params)
      @sake_log.sake = @sake
      @sake_log.save!
    rescue ActiveRecord::RecordInvalid => exception
      flash.now[:error] = t("defaults.flash_message.not_created", item: SakeLog.model_name.human)
      logger.error("-----ERROR-----#{Time.now}")
      logger.error(exception)
      logger.error(@sake)
      logger.error(@sake_log)
      logger.error("-----ERROR LOG END-----")
      render :new, status: :unprocessable_entity
      return
    end

    redirect_to sake_logs_path, success: t("defaults.flash_message.created", item: SakeLog.model_name.human)
  end

  private
  def sake_log_params
    params.require(:sake_log).permit(:rating, :aroma_strength, :taste_strength, :review,
                                      sake_attributes: [ :product_name ])
  end
end
