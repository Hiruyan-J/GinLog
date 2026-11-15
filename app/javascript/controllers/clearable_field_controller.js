// 「記録なし」に戻せる入力欄（スライダー・ラジオボタン）
// 送信するのは hidden field だけ（空文字 = 記録なし）
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="clearable-field"
export default class extends Controller {
  static targets = ["value", "input", "display"]
  static classes = ["blank"]

  connect() {
    this.updateAppearance()
  }

  // スライダーを動かした・ラジオボタンを選んだときに、その値を記録する
  record(event) {
    this.valueTarget.value = event.target.value
    this.updateAppearance()
  }

  // 「クリア」ボタン: 記録なしに戻す（スライダーのつまみは動かさない）
  clear() {
    this.valueTarget.value = ""
    this.inputTargets.forEach((input) => {
      if (input.type === "radio") input.checked = false
    })
    this.updateAppearance()
  }

  // 記録なしなら灰色にする
  updateAppearance() {
    const isBlank = this.valueTarget.value === ""
    this.blankClasses.forEach((className) => {
      this.displayTarget.classList.toggle(className, isBlank)
    })
  }
}
