# マイアカウント画面（本人専用）
#
# 「他ユーザーのプロフィール画面」は作らない方針のため、
# ここでは常に current_user だけを表示する。
# メールアドレスを表示する画面なので、他人が閲覧できる形に流用してはいけない。
class UsersController < ApplicationController
  def show
    @user = current_user
  end
end
