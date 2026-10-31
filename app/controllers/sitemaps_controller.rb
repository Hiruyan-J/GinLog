# 検索エンジン向けのサイトマップをアクセス時に DB から生成するコントローラ
class SitemapsController < ApplicationController
  skip_before_action :authenticate_user!

  # サイトマップに載せるレコードを取得する（XML は show.xml.builder で組み立てる）
  # @return [void]
  def show
    @sakes = Sake.select(:id, :updated_at).order(:id)
    @sake_logs = SakeLog.select(:id, :updated_at).order(:id)
  end
end
