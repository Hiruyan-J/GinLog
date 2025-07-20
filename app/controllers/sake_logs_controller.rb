class SakeLogsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]
  before_action :set_sake_log, only: %i[edit update destroy]

  def index
    @sake_logs = SakeLog.includes([ :user, :sake ]).order(created_at: :desc)
  end

  def new
    @sake_log = SakeLog.new
    @sake_log.build_sake
  end

  def create
    product_name =sake_log_params[:sake_attributes][:product_name].strip

    SakeLog.transaction do
      @sake = Sake.find_or_initialize_by(product_name: product_name)
      @sake_log = current_user.sake_logs.build(sake_log_params)
      @sake_log.sake = @sake
      @sake.save!
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

  def edit; end

  def update
    product_name =sake_log_params[:sake_attributes][:product_name].strip

    SakeLog.transaction do
      @sake = Sake.find_or_initialize_by(product_name: product_name)
      @sake_log.assign_attributes(sake_log_params)
      @sake_log.sake = @sake
      @sake.save!
      @sake_log.save!
    rescue ActiveRecord::RecordInvalid => exception
      flash.now[:error] = t("defaults.flash_message.not_updated", item: SakeLog.model_name.human)
      logger.error("-----ERROR-----#{Time.now}")
      logger.error(exception)
      logger.error(@sake)
      logger.error(@sake_log)
      logger.error("-----ERROR LOG END-----")
      render :edit, status: :unprocessable_entity
      return
    end

    redirect_to sake_logs_path, success: t("defaults.flash_message.updated", item: SakeLog.model_name.human)
  end


  def destroy
    if @sake_log.destroy
      redirect_to sake_logs_path, success: t("defaults.flash_message.deleted", item: SakeLog.model_name.human), status: :see_other
    else
      flash[:error] = t("defaults.flash_message.not_deleted", item: SakeLog.model_name.human)
      redirect_back fallback_location: sake_logs_path, status: :see_other
    end
  end

  private

  def set_sake_log
    @sake_log = current_user.sake_logs.find(params[:id])
  end

  def sake_log_params
    params.require(:sake_log).permit(:rating, :aroma_strength, :taste_strength, :review,
                                      sake_attributes: [ :product_name ])
  end
end
