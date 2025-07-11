class SakeLogsController < ApplicationController
  def index
    flash.now[:info] = "info_test"
    flash.now[:success] = "success_test"
    flash.now[:warning] = "wornig_test"
    flash.now[:error] = "error_test"
  end
end
