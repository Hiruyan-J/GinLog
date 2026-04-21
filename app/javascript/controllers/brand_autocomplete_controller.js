import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="brand-autocomplete"
// 銘柄オートコンプリートコントローラ
// 銘柄名を入力すると、さけのわAPIマスタから候補を表示する
// 候補選択時に蔵元を自動表示し、商品名フィールドにbrand_idを伝える
export default class extends Controller {
  static targets = [
    "input",          // 銘柄名テキスト入力(オートコンプリート対象)
    "hiddenBrandId",
    "dropdown",
    "breweryDisplay",  // 蔵元の自動表示エリア (readonly)(通常モードのみ)
    "manualFields",   // 銘柄手入力モード用フィールド群(蔵元手入力, 都道府県選択)
    "hiddenManualBrandMode"
  ]

  static values = {
    searchUrl: String,          // /api/brands/search
    initialBrandId: Number,     // 編集時の初期brand_id
    initialBrandName: String,  // 編集時の初期表示銘柄
    initialBreweryName: String  // 編集時の初期蔵元名
  }

  connect() {
    this.debounceTimer = null
    this.manualBrandMode = false

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
      this.hiddenBrandIdTarget.value = this.initialBrandIdValue
      this.inputTarget.value = this.initialBrandNameValue
      this.showBreweryDisplay(this.initialBreweryNameValue)
    }
  }

  // 入力欄クリック時に入力済みテキストで検索
  onClick() {
    // ドロップダウンが既に表示中なら何もしない
    if (!this.dropdownTarget.classList.contains("hidden")) return
    if (this.manualBrandMode) return

    const query = this.inputTarget.value.trim()
    if (query.length < 1) return

    this.searchBrands(query)
  }

  // 入力欄のキー入力ハンドラ (300msのdebounce(チャタリング防止))
  onInput() {
    clearTimeout(this.debounceTimer)
    
    // 銘柄手入力モード中はオートコンプリートしない(フリー入力のまま)
    const query = this.inputTarget.value.trim()

    if (this.manualBrandMode) return

    // 銘柄が選択済みだった場合、商品名側もリセットする
    const hadSelectedBrand = this.hiddenBrandIdTarget.value !== ""

    // 入力が変わったらbrand_idをクリア(再選択を促す)
    this.hiddenBrandIdTarget.value = ""
    this.hideBreweryDisplay()

    // 商品名コントローラに銘柄リセットを通知
    if (hadSelectedBrand) {
      this.element.dispatchEvent(new CustomEvent("brand-selected", {
        bubbles: true,
        detail: { brandId: null }
      }))
    }

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
      this.renderDropdown(data.brands, query)
    } catch (error) {
      console.error("銘柄検索エラー:", error)
    }
  }

  // 候補リストの描画（XSS対策: DOM APIで要素を構築）
  renderDropdown(brands, query) {
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
      button.dataset.breweryName = brand.brewery_name
      button.textContent = brand.label
      li.appendChild(button)
      ul.appendChild(li)
    })

    // 「該当する銘柄がない」オプションを末尾に追加
    if (query) {
      const newLi = document.createElement("li")
      const newButton = document.createElement("button")
      newButton.type = "button"
      newButton.className = "w-full text-left px-4 py-2 hover:bg-base-200 text-base-content/60 cursor-pointer"
      newButton.dataset.action = "click->brand-autocomplete#selectManualBrandMode"
      newButton.textContent = "該当する銘柄がない（手入力する）"
      newLi.appendChild(newButton)
      ul.appendChild(newLi)
    }

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

    this.exitManualBrandMode()

    // 蔵元を自動表示
    this.showBreweryDisplay(breweryName)

    this.closeDropdown()

    // 商品名コントローラにbrand_idの変更を通知(CustomEvent)
    this.element.dispatchEvent(new CustomEvent("brand-selected", {
      bubbles: true,
      detail: { brandId: parseInt(brandId, 10) }
    }))
  }

  selectManualBrandMode() {
    this.manualBrandMode = true
    this.hiddenManualBrandModeTarget.value = "true"
    // brand_id をクリア（銘柄手入力時は保存ロジックで Brand を作成する）
    this.hiddenBrandIdTarget.value = ""

    // 蔵元の readonly 表示を非表示にし、銘柄手入力モード用フィールドを表示
    this.hideBreweryDisplay()
    this.showManualFields()

    this.closeDropdown()

    // 商品名コントローラに銘柄リセットを通知
    this.element.dispatchEvent(new CustomEvent("brand-selected", {
      bubbles: true,
      detail: { brandId: null, manualBrandMode: true }
    }))
  }

  exitManualBrandMode() {
    this.manualBrandMode = false
    this.hiddenManualBrandModeTarget.value = ""
    this.hideManualFields()
  }

  // --- 蔵元表示の切り替え ---

  // 蔵元の読み取り専用フィールドに値をセットする
  showBreweryDisplay(text) {
    this.breweryDisplayTarget.value = text
    this.breweryDisplayTarget.parentElement.classList.remove("hidden")
  }

  // 蔵元の読み取り専用フィールドをクリアする
  hideBreweryDisplay() {
    this.breweryDisplayTarget.value = ""
    this.breweryDisplayTarget.parentElement.classList.add("hidden")
  }

  // 銘柄手入力モード用フィールド群の表示
  showManualFields() {
    this.manualFieldsTarget.classList.remove("hidden")
  }

  // 銘柄手入力モード用フィールドの非表示
  hideManualFields() {
    this.manualFieldsTarget.classList.add("hidden")
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
