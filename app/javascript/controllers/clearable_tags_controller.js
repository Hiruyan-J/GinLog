// 「記録なし」に戻せるタグ（チェックボックス）
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="clearable-tags"
export default class extends Controller {
  static targets = ["checkbox", "display", "intensity", "tag", "message"]
  static classes = ["blank", "locked"]

  connect() {
    this.sync()
  }

  // 「クリア」ボタン: この区分のタグのチェックを全部外す
  clear() {
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = false
    })
    this.updateAppearance()
  }

  // 強弱が 0（無し）ならタグを外して押せなくし、それ以外なら押せるように戻す
  sync() {
    this.locked = this.intensityTarget.value !== "" && Number(this.intensityTarget.value) === 0
    if (this.locked) {
      this.checkboxTargets.forEach((checkbox) => {
        checkbox.checked = false
      })
    }
    this.tagTargets.forEach((tag) => {
      this.lockedClasses.forEach((className) => tag.classList.toggle(className, this.locked))
    })
    this.messageTarget.classList.toggle("hidden", !this.locked)
    this.updateAppearance()
  }

  // 1つもチェックが無ければ灰色、あれば元の色に戻す（非活性のときは btn-disabled の見た目に任せ、灰色にしない）
  updateAppearance() {
    const isBlank = !this.locked && !this.checkboxTargets.some((checkbox) => checkbox.checked)
    this.blankClasses.forEach((className) => {
      this.displayTarget.classList.toggle(className, isBlank)
    })
  }
}
