# メールアドレス確認（確認リンク・確認メール再送）を扱うコントローラ
#
# Devise の実装をそのまま使い、show だけを上書きしている。
class Users::ConfirmationsController < Devise::ConfirmationsController
  # 確認リンクを処理する
  #
  # GET /users/confirmation?confirmation_token=xxxxx
  #
  # メールアプリやブラウザがリンクを先読みすると、同じリンクが 2 回開かれることがある。
  # 1 回目で確認が完了するため、2 回目は Devise が :already_confirmed エラーを返し、
  # 「メールアドレスが確認できました。」と「Eメールは既に登録済みです。」が
  # 同じ画面に並んでしまう。確認が済んでいるなら成功として扱い、ログイン画面へ送る。
  #
  # @return [void]
  def show
    self.resource = resource_class.confirm_by_token(params[:confirmation_token])
    yield resource if block_given?

    # 元の Devise の実装は `if resource.errors.empty?` だけ。
    # 「既に確認済み（:already_confirmed）」のときも成功として扱う。
    #
    # confirmed? で判定してはいけない。
    # メールアドレス変更の再確認が期限切れになった場合、元の confirmed_at が
    # 残っているため confirmed? は true のままで、変更が未反映なのに
    # 成功と誤判定してしまう（エラーは :confirmation_period_expired）。
    if resource.errors.empty? || resource.errors.added?(:email, :already_confirmed)
      set_flash_message!(:notice, :confirmed)
      respond_with_navigational(resource) { redirect_to after_confirmation_path_for(resource_name, resource) }
    else
      respond_with_navigational(resource.errors, status: :unprocessable_entity) { render :new }
    end
  end
end
