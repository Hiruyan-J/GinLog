# お問い合わせなど、決まった内容を表示するページを扱うコントローラ
class StaticPagesController < ApplicationController
  skip_before_action :authenticate_user!

  # 問い合わせを受け付ける Google フォームの URL
  CONTACT_FORM_URL = "https://docs.google.com/forms/d/e/1FAIpQLSf0RTxnbQKWb3_FBdpzyhCXlnfsAX9MrAijWnPKHI6ZrEcalA/viewform?usp=dialog".freeze

  # GET /
  # 未ログインなら TOPページを表示し、ログイン済みならタイムラインへ移動する
  # @return [void]
  def top
    return unless user_signed_in?

    # ログイン直後のメッセージ（「ログインしました」など）を、タイムラインまで持ち越す
    flash.keep
    redirect_to timeline_path
  end

  # GET /about
  # ログイン中でも TOPページを見られるように、リダイレクトせずに表示する
  # @return [void]
  def about
    render :top
  end

  def contact
    @contact_form_url = CONTACT_FORM_URL
  end

  def privacy; end

  def terms; end

  def install; end
end
