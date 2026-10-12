# Google ログインのコールバックを扱うコントローラ
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # Google での認証が成功したあとに呼ばれる
  #
  # GET /users/auth/google_oauth2/callback
  #
  # @return [void]
  def google_oauth2
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      set_flash_message(:notice, :success, kind: "Google")
      # 初回だけ、Google の名前がそのまま入っていることを知らせる
      flash[:info] = t("devise.omniauth_callbacks.name_changeable") if @user.previously_new_record?
      sign_in_and_redirect @user, event: :authentication
    else
      redirect_to new_user_session_path, alert: t("devise.omniauth_callbacks.failure")
    end
  end
end
