class SakeLogsController < ApplicationController
  def index
    @sake_logs = SakeLog.includes(:user)
  end
end
