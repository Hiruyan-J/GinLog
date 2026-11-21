// 「記録なし」に戻せるタグ（チェックボックス）
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="clearable-tags"
export default class extends Controller {
  static targets = ["checkbox", "display"]
  static classes = ["blank"]

  connect() {
    this.updateAppearance()
  }

  // 「クリア」ボタン: この区分のタグのチェックを全部外す
  clear() {
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = false
    })
    this.updateAppearance()
  }

  // 1つもチェックが無ければ灰色、あれば元の色に戻す
  updateAppearance() {
    const isBlank = !this.checkboxTargets.some((checkbox) => checkbox.checked)
    this.blankClasses.forEach((className) => {
      this.displayTarget.classList.toggle(className, isBlank)
    })
  }
}
