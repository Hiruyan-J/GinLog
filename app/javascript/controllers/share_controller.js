import { Controller } from "@hotwired/stimulus"

// 「コピーしました」を表示しておく時間（ミリ秒）
const COPIED_MESSAGE_DURATION = 1500

// Connects to data-controller="share"
export default class extends Controller {

  static values = {
    url: String,  // url   … シェア先の絶対 URL
    text: String, // text  … 投稿文（ShareHelper で組み立てたもの）
    title: String // title … 共有メニューに渡すタイトル
  }
  // copyLabel … 「URLをコピー」の文言を入れている span 要素
  static targets = ["copyLabel"]

  connect() {
    // 元の文言（「URLをコピー」）を覚えておく。copy の中で読むと、連打したときに「コピーしました」を覚えてしまうため
    this.defaultCopyLabel = this.copyLabelTarget.textContent
  }

  // share アイコン（<summary>）のクリック
  // navigator.share が使える場合は、<details> の標準の開閉動作を止め、共有メニューを表示する。
  // 使えない場合は標準動作に任せ、<details> を開閉して予備メニューを表示する。
  async toggle(event) {
    if (!navigator.share) return

    event.preventDefault()
    try {
      await navigator.share({ title: this.titleValue, text: this.textValue, url: this.urlValue })
    } catch (error) {
      // 共有メニューをユーザーが閉じたときは AbortError になる。操作ミスではないので何もしない
      if (error.name !== "AbortError") console.error(error)
    }
  }

  // シェア先 URL をクリップボードにコピーする
  async copy() {
    try {
      await navigator.clipboard.writeText(this.urlValue)
    } catch (error) {
      console.error(error)
      return
    }

    this.copyLabelTarget.textContent = "コピーしました"
    setTimeout(() => {
      this.copyLabelTarget.textContent = this.defaultCopyLabel
      this.close()
    }, COPIED_MESSAGE_DURATION)
  }

  // メニューの外がクリックされたら閉じる（data-action の click@window から呼ぶ）
  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  // メニューを閉じる（this.element は <details>。open 属性を外すと閉じる）
  close() {
    this.element.removeAttribute("open")
  }
}
