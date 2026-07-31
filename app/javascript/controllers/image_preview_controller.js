import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // input       … 実際の <input type="file">（画面上は非表示）
  // preview     … 選んだ画像を表示する <img>
  // placeholder … 画像がないときに出すアイコン
  // removeField … 「削除」チェックボックス（既存画像があるときだけ存在する）
  // clearButton … 「選択を取り消す」ボタン（画像を選んだときだけ表示する）
  static targets = ["input", "preview", "placeholder", "removeField", "clearButton"]

  // 編集画面で「選択を取り消す」を押した場合、元画像に戻すために
  // 最初の src を保存。
  connect() {
    this.originalSrc = this.previewTarget.getAttribute("src")
  }

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

    this.clearButtonTarget.classList.remove("hidden")
  }

  // 選んだ画像を取り消す
  // input の value を空にすることで、サーバーへは何も送られなくなる
  clear() {
    this.inputTarget.value = ""
    this.revokePreviewUrl()

    if (this.originalSrc) {
      // 編集時: 差し替えをやめて元の保存済み画像に戻す
      this.previewTarget.src = this.originalSrc
    } else {
      // 新規時: 何も選んでいない空の枠に戻す
      this.previewTarget.removeAttribute("src")
      this.previewTarget.classList.add("hidden")
      this.placeholderTarget.classList.remove("hidden")
    }

    this.clearButtonTarget.classList.add("hidden")
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
