import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// インストールダイアログを開くためのイベント。Turbo でページを移動しても残るよう、クラスの外に置く
let deferredInstallPrompt = null

// Chrome・Edge がインストールできると判断したときに発火する（Safari では発火しない）
window.addEventListener("beforeinstallprompt", (event) => {
  deferredInstallPrompt = event
})

// インストールが終わったら、使い終わったイベントを捨てる
window.addEventListener("appinstalled", () => {
  deferredInstallPrompt = null
  // インストールされたことを GA4 に送る（gtag が使えないときは送らない）
  if (typeof window.gtag === "function") window.gtag("event", "pwa_install")
})

// Connects to data-controller="pwa-install"
export default class extends Controller {
  connect() {
    // アプリとして開いているときは、メニュー項目（this.element は li）を隠す
    if (this.isStandalone()) this.element.hidden = true
  }

  // 「アプリとしてインストール」のクリック
  async install(event) {
    // イベントがないときは、リンクのまま手順のページに移動させる
    if (!deferredInstallPrompt) return

    // リンクの移動を止め、リンクからフォーカスを外してハンバーガーメニューを閉じる
    event.preventDefault()
    const link = event.currentTarget
    link.blur()

    // prompt() は 1 つのイベントにつき 1 回しか使えないため、先に手放す
    const installPrompt = deferredInstallPrompt
    deferredInstallPrompt = null
    try {
      await installPrompt.prompt()
      // キャンセルされたら、手順のページに移動する（インストールしたときは "accepted"）
      const { outcome } = await installPrompt.userChoice
      if (outcome === "dismissed") Turbo.visit(link.href)
    } catch (error) {
      // ダイアログを開けなかったときは、手順のページに移動する
      console.error(error)
      Turbo.visit(link.href)
    }
  }

  // アプリとして開いているか（古い iPhone の Safari は navigator.standalone で判定する）
  isStandalone() {
    return window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone === true
  }
}
