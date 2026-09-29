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
  // nativeShareItem … 「その他のアプリで共有」の li 要素
  static targets = ["copyLabel", "nativeShareItem"]

  connect() {
    // 元の文言（「URLをコピー」）を覚えておく。copy の中で読むと、連打したときに「コピーしました」を覚えてしまうため
    this.defaultCopyLabel = this.copyLabelTarget.textContent
    // OS の共有メニューが使える環境の場合、「その他のアプリで共有」を出す
    if (navigator.share) this.nativeShareItemTarget.hidden = false
  }

  // 「その他のアプリで共有」のクリック。OS の共有メニュー（LINE・メッセージなど）を開く
  async nativeShare() {
    this.close()
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
