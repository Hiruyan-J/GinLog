class TimelineController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]

  def index
    @sake_logs = SakeLog.includes([ :user, :sake ]).order(created_at: :desc)
  end
end
