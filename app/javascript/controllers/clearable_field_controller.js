// 「記録なし」に戻せる入力欄（スライダー・ラジオボタン）
// 送信するのは hidden field だけ（空文字 = 記録なし）
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="clearable-field"
export default class extends Controller {
  static targets = ["value", "input", "display"]
  static classes = ["blank"]
  static values = { required: Boolean }
  static REQUIRED_MESSAGE = "スライダーを動かすか、タップして選んでください"

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

  // 記録なしなら灰色、記録ありなら元の色に戻す（必須の欄はエラーの付け外しも行う）
  updateAppearance() {
    const isBlank = this.valueTarget.value === ""
    this.blankClasses.forEach((className) => {
      this.displayTarget.classList.toggle(className, isBlank)
    })
    this.updateValidity(isBlank)
  }

  // 必須の欄が未入力ならエラーを付けて送信を止め、入力済みならエラーを外す
  updateValidity(isBlank) {
    if (!this.requiredValue) return

    const message = isBlank ? this.constructor.REQUIRED_MESSAGE : ""
    this.inputTargets.forEach((input) => input.setCustomValidity(message))
  }
}
