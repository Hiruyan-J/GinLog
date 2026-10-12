# お問い合わせなど、決まった内容を表示するページを扱うコントローラ
class StaticPagesController < ApplicationController
  skip_before_action :authenticate_user!

  # 問い合わせを受け付ける Google フォームの URL
  CONTACT_FORM_URL = "https://docs.google.com/forms/d/e/1FAIpQLSf0RTxnbQKWb3_FBdpzyhCXlnfsAX9MrAijWnPKHI6ZrEcalA/viewform?usp=dialog".freeze

  def contact
    @contact_form_url = CONTACT_FORM_URL
  end

  def privacy; end
end
