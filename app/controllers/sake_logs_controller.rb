class SakeLogsController < ApplicationController
  def index
    @sake_logs = SakeLog.includes(:sake)
  end
end
