import { Controller } from "@hotwired/stimulus"
import { resizeImage } from "../utils/image_resizer"

export default class extends Controller {
  // input       … 実際の <input type="file">（画面上は非表示）
  // preview     … 選んだ画像を表示する <img>
  // placeholder … 画像がないときに出すアイコン
  // removeField … 「削除」チェックボックス（既存画像があるときだけ存在する）
  // clearButton … 「選択を取り消す」ボタン（画像を選んだときだけ表示する）
  static targets = ["input", "preview", "placeholder", "removeField", "clearButton"]

  // 登録する画像の長辺の上限(px)。アップロード時間と保存容量を抑えるため
  static MAX_DIMENSION = 1600

  // 編集画面で「選択を取り消す」を押した場合、元画像に戻すために
  // 最初の src を保存。
  connect() {
    this.originalSrc = this.previewTarget.getAttribute("src")
  }

  // ファイルが選択されたときに呼ばれる
  async select(event) {
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

    // 送信するファイルを縮小版に差し替える
    await this.replaceWithResizedFile(event.target, file)
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

  // 入力欄の中身を縮小後のファイルに差し替える
  // 差し替えに失敗した場合は元ファイルのまま送る
  async replaceWithResizedFile(input, file) {
    const resized = await resizeImage(file, this.constructor.MAX_DIMENSION)
    // 縮小が不要・失敗のときは元ファイルが返ってくるので何もしない
    if (resized === file) return
    // 縮小中に別の画像を選び直した・取り消した場合は差し替えない
    if (input.files[0] !== file) return

    try {
      // input.files の中身は直接変更できないため、
      // DataTransfer で新しい FileList を作って丸ごと差し替える
      const dataTransfer = new DataTransfer()
      dataTransfer.items.add(resized)
      input.files = dataTransfer.files  // DataTransferからFileListを取得し、入力欄のファイル一覧を差し替える
    } catch (error) {
      console.error("画像の差し替えに失敗しました:", error)
    }
  }
}
