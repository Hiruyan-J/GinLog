import { Controller } from "@hotwired/stimulus"

// ratingのnull状態（未選択）と0状態（クリア済み）を視覚的に区別するコントローラー
// - null（未選択）: 星が灰色（bg-stone-400）→ バリデーションで弾く
// - 0（クリア済み）: 星が黄色（bg-yellow-300）で未点灯 → 有効な値
// - 1〜5: 星が黄色で点灯 → 有効な値
export default class extends Controller {
  static targets = ["star"]

  connect() {
    this.updateStarColors()
  }

  // ラジオボタンが選択された時（星クリック・クリアボタン共通）
  select() {
    this.updateStarColors()
  }

  //  星の色を更新する
  // - ラジオボタンが未選択（null）→ 灰色
  // - ラジオボタンが選択済み（0〜5）→ 黄色
  updateStarColors() {
    const checked = this.element.querySelector('input[type="radio"]:checked')
    const isNull = !checked

    this.starTargets.forEach(star => {
      if (isNull) {
        // ratingがnull（未選択）
        star.classList.remove("bg-yellow-300")
        star.classList.add("bg-stone-400")
      } else {
        // ratingが0〜5（選択済み）
        star.classList.remove("bg-stone-400")
        star.classList.add("bg-yellow-300")
      }
    })
  }
}
