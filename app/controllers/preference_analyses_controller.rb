# 好み分析画面（本人専用）
class PreferenceAnalysesController < ApplicationController
  # GET /preference_analysis
  # @return [void]
  def show
    @analysis = PreferenceAnalysis.new(current_user)
    # 産地別分析の地図に並べる47都道府県
    @prefectures = Area.prefectures
  end
end
