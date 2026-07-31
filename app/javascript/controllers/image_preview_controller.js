import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // input       … 実際の <input type="file">（画面上は非表示）
  // preview     … 選んだ画像を表示する <img>
  // placeholder … 画像がないときに出すアイコン
  // removeField … 「削除」チェックボックス（既存画像があるときだけ存在する）
  static targets = ["input", "preview", "placeholder", "removeField"]

  // ファイルが選択されたときに呼ばれる
  select(event) {
    const file = event.target.files[0]
    if (!file) return

    // 前に作ったプレビュー用URLを解放
    this.revokePreviewUrl()

    // ブラウザ内でファイルを指す一時的なURLを作る（サーバー送信前に表示できる）
    this.previewUrl = URL.createObjectURL(file)
    this.previewTarget.src = this.previewUrl
    this.previewTarget.classList.remove("hidden")
    this.placeholderTarget.classList.add("hidden")

    // 新しい画像を選択したため、「削除する」のチェック解除
    if (this.hasRemoveFieldTarget) {
      this.removeFieldTarget.checked = false
    }
  }

  // 画面から取り除かれるときに一時URLを解放する
  disconnect() {
    this.revokePreviewUrl()
  }

  revokePreviewUrl() {
    if (this.previewUrl) {
      URL.revokeObjectURL(this.previewUrl)
      this.previewUrl = null
    }
  }
}
