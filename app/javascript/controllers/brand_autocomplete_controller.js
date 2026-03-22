import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="brand-autocomplete"
// 銘柄オートコンプリートコントローラ
// 銘柄名を入力すると、さけのわAPIマスタから候補を表示する
// 候補選択時に蔵元を自動表示し、商品名フィールドにbrand_idを伝える
export default class extends Controller {
  static targets = [
    "input",          // 銘柄名テキスト入力(オートコンプリート対象)
    "hiddenBrandId",  // brand_id の hidden フィールド
    "dropdown",       // 候補リストのドロップダウン
    "breweryDisplay"  // 蔵元の自動表示エリア (readonly)
  ]

  static values = {
    searchUrl: String,          // /api/brands/search
    initialBrandId: Number,     // 編集時の初期brand_id
    initialBrandName: String,  // 編集時の初期表示銘柄
    initialBreweryName: String  // 編集時の初期蔵元名
  }

  connect() {
    this.debounceTimer = null
    // プルダウン外をクリックするとドロップダウンを閉じるためのリスナー
    this.boundHandleOutsideClick = this.handleOutsideClick.bind(this)
    document.addEventListener("click", this.boundHandleOutsideClick)

    // 編集時: 初期値を復元
    this.restoreInitialValues()
  }

  disconnect() {
    document.removeEventListener("click", this.boundHandleOutsideClick)
    clearTimeout(this.debounceTimer)
  }

  // 編集時に初期値を復元
  restoreInitialValues() {
    if (this.initialBrandIdValue && this.initialBrandIdValue > 0) {
      this.inputTarget.value = this.initialBrandNameValue
      this.showBreweryDisplay(this.initialBreweryNameValue)
    }
  }

  // 入力欄クリック時に入力済みテキストで検索
  onClick() {
    // ドロップダウンが既に表示中なら何もしない
    if (!this.dropdownTarget.classList.contains("hidden")) return

    const query = this.inputTarget.value.trim()
    if (query.length < 1) return

    this.searchBrands(query)
  }

  // 入力欄のキー入力ハンドラ (300msのdebounce(チャタリング防止))
  onInput() {
    clearTimeout(this.debounceTimer)
    const query = this.inputTarget.value.trim()

    // 入力が変わったらbrand_idをクリア(再選択を促す)
    this.hiddenBrandIdTarget.value = ""
    this.hideBreweryDisplay()

    if (query.length < 1) {
      this.closeDropdown()
      return
    }

    // 300ms入力が止まったら検索
    this.debounceTimer = setTimeout(() => {
      this.searchBrands(query)
    }, 300)
  }

  // APIへの検索リクエスト
  async searchBrands(query) {
    try {
      const url = new URL(this.searchUrlValue, window.location.origin)
      url.searchParams.set("q", query)

      const response = await fetch(url, {
        headers: { "Accept": "application/json" },
        credentials: "same-origin"
      })

      if (!response.ok) return

      const data = await response.json()
      this.renderDropdown(data.brands)
    } catch (error) {
      console.error("銘柄検索エラー:", error)
    }
  }

  // 候補リストの描画（XSS対策: DOM APIで要素を構築）
  renderDropdown(brands) {
    const ul = document.createElement("ul")
    ul.className = "flex flex-col bg-base-100 border border-base-300 rounded-box shadow-lg w-full max-h-60 overflow-y-auto list-none p-2"

    brands.forEach(brand => {
      const li = document.createElement("li")
      const button = document.createElement("button")
      button.type = "button"
      button.className = "w-full text-left px-4 py-2 hover:bg-base-200 cursor-pointer"
      button.dataset.action = "click->brand-autocomplete#selectBrand"
      button.dataset.brandId = brand.id
      button.dataset.brandName = brand.name
      button.dataset.brandLabel = brand.label
      button.dataset.breweryName = `${brand.brewery_name}（${brand.area_name}）`
      button.textContent = brand.label
      li.appendChild(button)
      ul.appendChild(li)
    })

    this.dropdownTarget.innerHTML = ""
    this.dropdownTarget.appendChild(ul)
    this.dropdownTarget.classList.remove("hidden")
  }

  // 銘柄候補を選択したとき
  selectBrand(event) {
    const button = event.currentTarget
    const brandId = button.dataset.brandId
    const breweryName = button.dataset.breweryName

    // hidden フィールドにbrand_idをセット
    this.hiddenBrandIdTarget.value = brandId

    // 入力欄に銘柄を表示
    this.inputTarget.value = button.dataset.brandName

    // 蔵元を自動表示
    this.showBreweryDisplay(breweryName)

    this.closeDropdown()

    // 商品名コントローラにbrand_idの変更を通知(CustomEvent)
    this.element.dispatchEvent(new CustomEvent("brand-selected", {
      bubbles: true,
      detail: { brandId: parseInt(brandId) }
    }))
  }

  // --- 蔵元表示の切り替え ---

  // 蔵元の読み取り専用フィールドに値をセットする
  showBreweryDisplay(text) {
    this.breweryDisplayTarget.value = text
  }

  // 蔵元の読み取り専用フィールドをクリアする
  hideBreweryDisplay() {
    this.breweryDisplayTarget.value = ""
  }

  // ---　ドロップダウン制御 ---
  closeDropdown() {
    this.dropdownTarget.classList.add("hidden")
    this.dropdownTarget.innerHTML = ""
  }

  // コントローラ外クリックでドロップダウンを閉じる
  handleOutsideClick(event) {
    if (!this.dropdownTarget.contains(event.target) && !this.inputTarget.contains(event.target)) {
      this.closeDropdown()
    }
  }
}
