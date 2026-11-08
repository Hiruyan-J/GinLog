# 日本酒記録へのコメントの投稿・編集・削除
class CommentsController < ApplicationController
  before_action :set_sake_log, only: %i[create]
  before_action :set_comment, only: %i[edit update destroy]

  def create
    @comment = @sake_log.comments.build(comment_params.merge(user: current_user))

    if @comment.save
      render :create
    else
      # エラーメッセージ付きのフォームに差し替える
      render turbo_stream: turbo_stream.update(
        "comment_form",
        partial: "comments/form",
        locals: { sake_log: @sake_log, comment: @comment }
      ), status: :unprocessable_entity
    end
  end

  def edit
    return redirect_to sake_log_path(@sake_log) unless turbo_frame_request?
    render :edit
  end

  def update
    if @comment.update(comment_params)
      render :update
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @comment.destroy!
    render :destroy
  end

  private

  def set_sake_log
    @sake_log = SakeLog.find(params[:sake_log_id])
  end

  # 自分のコメントの中から探すので、他人のコメントは見つからず 404 になる
  # コメント先の記録は、件数の更新やキャンセルリンクで使う
  # @return [void]
  def set_comment
    @comment = current_user.comments.find(params[:id])
    @sake_log = @comment.sake_log
  end

  def comment_params
    params.require(:comment).permit(:body)
  end
end
