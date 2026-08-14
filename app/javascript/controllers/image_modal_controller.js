import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="image-modal"
export default class extends Controller {
  // dialog  … モーダル本体（<dialog class="modal">）
  // image   … 拡大画像を表示する <img>
  // caption … 画像の種類（表ラベル・裏ラベルなど）を出す <p>
  static targets = ["dialog", "image", "caption"]

  // 画像ボタンから渡されたURL・キャプションを使ってモーダルを開く
  open(event) {
    const { url, caption } = event.params

    this.imageTarget.src = url
    this.captionTarget.textContent = caption
    // showModal() で開くと、背景が暗くなり Escキーでも閉じられる（<dialog> の標準機能）
    this.dialogTarget.showModal()
  }

  // Turbo でページを離れるときに、開いたままのモーダルが
  // 次に戻ってきたときのキャッシュに残らないようにする
  disconnect() {
    if (this.hasDialogTarget && this.dialogTarget.open) {
      this.dialogTarget.close()
    }
  }
}
