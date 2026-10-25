import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="auto-submit"
// フォームに付け、中の入力から submit を呼ぶと、そのフォームを送信する
// 日本酒検索の4象限で、チェックを切り替えたらすぐ検索するために使う
export default class extends Controller {
  submit() {
    // form.submit() と違い、requestSubmit() は submit イベントを発生させるので Turbo Drive が検知できる
    // Turbo Drive は返ってきた HTML で <body> を差し替える（CSS・JS は読み込み直さない）
    this.element.requestSubmit()
  }
}
