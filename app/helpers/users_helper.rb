# 投稿者アイコン（shared/_user_avatar）の表示ロジックをまとめたヘルパー
#
# DaisyUI の avatar-placeholder に名前の頭文字を表示する方式で実装。
# 将来ユーザーがアイコン画像を設定できるようになった際に、
# パーシャル側で「画像があれば画像 / なければ頭文字」に分岐するだけで差し替えられる。
module UsersHelper
  # 投稿者アイコンの背景色・文字色のパレット
  #
  # user.id をこの配列の要素数で割った余りで色を決めるため、
  # 同じユーザーには常に同じ色が付く（リロードしても変わらない）。
  AVATAR_COLOR_CLASSES = [
    "bg-sky-200 text-sky-900",
    "bg-emerald-200 text-emerald-900",
    "bg-amber-200 text-amber-900",
    "bg-rose-200 text-rose-900",
    "bg-violet-200 text-violet-900",
    "bg-teal-200 text-teal-900"
  ].freeze

  # 投稿者アイコンの大きさプリセット
  AVATAR_SIZES = {
    sm: "w-10 h-10 text-lg", # 一覧カード（タイムライン）
    md: "w-12 h-12 text-xl"  # 詳細画面
  }.freeze

  # 投稿者アイコンに表示する頭文字を返す
  #
  # @param user [User] 表示対象のユーザー
  # @return [String] 名前の先頭1文字（名前が空文字のときは "?"）
  def user_avatar_initial(user)
    user.name.to_s.strip.first || "?"
  end

  # ユーザーごとに固定の背景色・文字色クラスを返す
  #
  # @param user [User] 表示対象のユーザー
  # @return [String] Tailwind CSS の背景色・文字色クラス
  def user_avatar_color_class(user)
    AVATAR_COLOR_CLASSES[user.id % AVATAR_COLOR_CLASSES.size]
  end

  # 投稿者アイコンの大きさクラスを返す
  #
  # @param size [Symbol] サイズ名（:sm = 一覧カード / :md = 詳細画面）
  # @return [String] Tailwind CSS の幅・高さ・文字サイズクラス
  def user_avatar_size_class(size)
    AVATAR_SIZES.fetch(size)
  end
end
