# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  name                   :string           not null
#  provider               :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  uid                    :string
#  unconfirmed_email      :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_provider_and_uid      (provider,uid) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable,
         :omniauthable, omniauth_providers: %i[google_oauth2]

  validates :name, presence: true
  has_many :sake_logs, dependent: :destroy
  has_many :label_extraction_logs, dependent: :destroy

  # Google の認証情報に対応するユーザーを返す（いなければ作る）
  # @param auth [OmniAuth::AuthHash] Google から届いた認証情報
  # @return [User] 保存に失敗した場合は persisted? が false のユーザー
  def self.from_omniauth(auth)
    user = find_by(provider: auth.provider, uid: auth.uid)
    return user if user

    # Google 側で未確認のメールアドレスは nil で届く（その場合は保存に失敗する）
    user = find_or_initialize_by(email: auth.info.email.to_s.downcase)
    user.link_omniauth(auth)
    user
  end

  # Google アカウントをひも付けて保存する
  # @param auth [OmniAuth::AuthHash] Google から届いた認証情報
  # @return [Boolean] 保存成功なら true
  def link_omniauth(auth)
    self.provider = auth.provider
    self.uid = auth.uid
    self.name = auth.info.name if new_record?
    # 新規と、メール未確認の既存アカウントは、パスワードを作り直して確認済みにする
    unless confirmed?
      self.password = Devise.friendly_token[0, 20]
      skip_confirmation!
    end
    save
  end

  def google_account?
    provider == "google_oauth2"
  end

  def own?(object)
    id == object&.user_id
  end
end
