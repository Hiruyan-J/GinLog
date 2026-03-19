import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="product-name-autocomplete"
// 商品名オートコンプリートコントローラ
// 銘柄選択後、その銘柄に紐づく既存の商品名(Sakeレコード)から候補を表示
// 既存商品を選択すればSakeレコードの重複を防ぐ。新規入力も可
export default class extends Controller {
  static targets = [
    "input",        // 商品名のテキスト入力
    "hiddenSakeId", // sake_id の hidden フィールド(既存Sake選択時にセット)
    "dropdown"      // 候補リストのドロップダウン
  ]

  static values = {
    searchUrl: String,          // /api/sakes/search
    brandId: Number,            // 選択中のbrand_id（銘柄オートコンプリートコントローラから受け取る）
    initialSakeId: Number,      // 編集時の初期sake_id
    initialProductName: String  // 編集時の初期商品名
  }

  connect() {
    this.debounceTimer = null
    // クリック外でドロップダウンを閉じるためのリスナー
    this.boundHandleOutsideClick = this.handleOutsideClick.bind(this)
    document.addEventListener("click", this.boundHandleOutsideClick)

    // 銘柄選択イベントをリスナー登録
    this.boundOnBrandSelected = this.onBrandSelected.bind(this)
    document.addEventListener("brand-selected", this.boundOnBrandSelected)

    // 編集時: 初期値を復元
    this.restoreInitialValues()
  }

  disconnect() {
    document.removeEventListener("click", this.boundHandleOutsideClick)
    document.removeEventListener("brand-selected", this.boundOnBrandSelected)
    clearTimeout(this.debounceTimer)
  }

  // 編集時に初期値を復元
  restoreInitialValues() {
    if (this.initialProductNameValue) {
      this.inputTarget.value = this.initialProductNameValue
    }
    if (this.initialSakeIdValue && this.initialSakeIdValue > 0) {
      this.hiddenSakeIdTarget.value = this.initialSakeIdValue
    }
    // brand_idの初期値があれば入力欄を有効にする
    if (this.brandIdValue && this.brandIdValue > 0) {
      this.inputTarget.disabled = false
    }
  }

  // 銘柄選択イベントのハンドラ(brand-autocompleteコントローラから受け取る)
  onBrandSelected(event) {
    const { brandId } = event.detail
    this.brandIdValue = brandId || 0

    // 銘柄が変わったら商品名リセット
    this.inputTarget.value = ""
    this.hiddenSakeIdTarget.value = ""
    this.closeDropdown()

    if (brandId) {
      // 銘柄が選択された場合: 商品名入力を有効にする
      this.inputTarget.disabled = false
      this.inputTarget.focus()
    } else {
      // 銘柄が未選択の場合: 商品名入力を無効にする
      this.inputTarget.disabled = true
    }
  }

  // 入力欄のキー入力ハンドラ（300msのdebounce）
  onInput() {
    clearTimeout(this.debounceTimer)

    // 入力が変わったらsake_idをクリア(再選択を促す)
    this.hiddenSakeIdTarget.value = ""

    const query = this.inputTarget.value.trim()

    // brand_idが無い場合はオートコンプリートしない
    if (!this.brandIdValue || this.brandIdValue === 0 ) {
      this.closeDropdown()
      return
    }

    // 1文字未満の場合でもbrand_idに紐づく全商品を表示
    this.debounceTimer = setTimeout(() => {
      this.searchSakes(query)
    }, 300);
  }

  // APIへの検索リクエスト
  async searchSakes(query) {
    try {
      const url = new URL(this.searchUrlValue, windows.location.origin)
      url.searchParams.set("brand_id", this.brandIdValue)
      if (query) {
        url.searchParams.set("q", query)
      }

      const response = await fetch(url, {
        headers: { "Accept": "application/json" },
        credentials: "same-origin"
      })

      if (!response.ok) return

      const data = await response.json()
      this.renderDropdown(data.sakes)
    } catch (error) {
      console.error("商品名検索エラー:", error)
    }
  }

  // 候補リストの描画（XSS対策: DOM APIで要素を構築）
  renderDropdown(sakes) {
    const ul = document.createElement("ul")
    ul.className = "menu bg-base-100 border border-base-300 rounded-box shadow-lg w-full max-h-60 overflow-y-auto"

    sakes.forEach(sake => {
      const li = document.createElement("li")
      const button = document.createElement("button")
      button.type = "button"
      button.className = "w-full text-left px-4 py-2 hover:bg-base-200 cursor-pointer"
      button.dataset.action = "click->product-name-autocomplete#selectSake"
      button.dataset.sakeId = sake.id
      button.dataset.productName = sake.product_name
      button.textContent = sake.product_name
      li.appendChild(button)
      ul.appendChild(li)
    })

    // 「新しい商品名として登録」オプションを末尾に追加
    const newLi = document.createElement("li")
    const newButton = document.createElement("button")
    newButton.type = "button"
    newButton.className = "w-full text-left px-4 py-2 hover:bg-base-200 text-base-content/60 cursor-pointer"
    newButton.dataset.action = "click->product-name-autocomplete#selectNewProduct"
    newButton.textContent = "新しい商品名として登録"
    newLi.appendChild(newButton)
    ul.appendChild(newLi)

    this.dropdownTarget.innerHTML = ""
    this.dropdownTarget.appendChild(ul)
    this.dropdownTarget.classList.remove("hidden")
  }

  // 既存の商品名を選択したとき
  selectSake(event) {
    const button = event.currentTarget
    const sakeId = button.dataset.sakeId
    const productName = button.dataset.productName

    // hidden フィールドにsake_idをセット
    this.hiddenSakeIdTarget.value = sakeId
    // 入力欄に商品名を表示
    this.inputTarget.value = productName

    this.closeDropdown()
  }

  // 「新しい商品名として登録」を選択したとき
  selectNewProduct() {
    // sake_idをクリア(新規作成)
    this.hiddenSakeIdTarget.value = ""
    // 入力欄のテキストはそのまま保持(ユーザーが入力した商品名を利用)

    this.closeDropdown
  }

  // --- ドロップダウン制御 ---

  closeDropdown() {
    this.dropdownTarget.classList.add("hidden")
    this.dropdownTarget.innerHTML = ""
  }

  // コントローラ外クリックでドロップダウンを閉じる
  handleOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.closeDropdown()
    }
  }
}
