# アカウント登録・編集を扱うコントローラ
#
# Devise の実装をそのまま使い、更新時の保存処理だけを上書きしている。
class Users::RegistrationsController < Devise::RegistrationsController
  protected

  # アカウント情報を更新する（Google 登録ユーザーはユーザー名のみ・パスワード不要）
  # @param resource [User] 更新するユーザー
  # @param params [ActionController::Parameters] 許可済みのフォーム入力値
  # @return [Boolean] 更新成功なら true
  def update_resource(resource, params)
    return super unless resource.google_account?

    resource.update_without_password(params.slice(:name))
  end
end
