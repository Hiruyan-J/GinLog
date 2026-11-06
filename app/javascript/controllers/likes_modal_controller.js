import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="likes-modal"
export default class extends Controller {
  // frame の読み込みが終わったらモーダルを開く
  open() {
    this.element.showModal()
  }

  // モーダルを閉じて、frame の読み込み元を消す
  close() {
    if (this.element.open) {
      this.element.close()
    }
    this.element.querySelector("turbo-frame").removeAttribute("src")
  }
}
