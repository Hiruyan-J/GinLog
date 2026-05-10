import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="brand-autocomplete"
// 銘柄オートコンプリートコントローラ
// 銘柄名を入力すると、さけのわAPIマスタから候補を表示する
// 候補選択時に蔵元を自動表示し、商品名フィールドにbrand_idを伝える
export default class extends Controller {
  static targets = [
    "input",          // 銘柄名テキスト入力(オートコンプリート対象)
    "hiddenBrandId",
    "dropdown"
  ]

  static values = {
    searchUrl: String,          // /api/brands/search
    initialBrandId: Number,     // 編集時の初期brand_id
    initialBrandName: String    // 編集時の初期表示銘柄
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
      this.hiddenBrandIdTarget.value = this.initialBrandIdValue
      this.inputTarget.value = this.initialBrandNameValue
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

    // 銘柄が選択済みだった場合、brand:cleared を発火して下流にリセットを通知
    const hadSelectedBrand = this.hiddenBrandIdTarget.value !== ""
    // 入力が変わったらbrand_idをクリア(再選択を促す)
    this.hiddenBrandIdTarget.value = ""

    // 商品名コントローラに銘柄リセットを通知
    if (hadSelectedBrand) {
      this.dispatchBrandCleared()
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

  // 候補リストの描画 + 「新しい銘柄として登録」ボタン
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
      button.dataset.breweryId = brand.brewery_id
      button.dataset.breweryName = brand.brewery_name
      button.dataset.areaId = brand.area_id
      button.dataset.areaName = brand.area_name
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
      newButton.dataset.action = "click->brand-autocomplete#selectNewBrand"
      newButton.textContent = "新しい銘柄として登録"
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
    const brandId = parseInt(button.dataset.brandId, 10)
    const breweryId = parseInt(button.dataset.breweryId, 10)
    const areaId = parseInt(button.dataset.areaId, 10)

    // hidden フィールドにbrand_idをセット
    this.hiddenBrandIdTarget.value = brandId
    // 入力欄に銘柄を表示
    this.inputTarget.value = button.dataset.brandName

    this.closeDropdown()

    // 下流コントローラに銘柄選択を通知
    document.dispatchEvent(new CustomEvent("brand:selected", {
      detail: {
        brandId,
        brandName: button.dataset.brandName,
        breweryId,
        breweryName: button.dataset.breweryName,
        areaId,
        areaName: button.dataset.areaName
      }
    }))
  }

  selectNewBrand() {
    // brand_id をクリア（保存時に manual_brand_name から Brand を作成する）
    this.hiddenBrandIdTarget.value = ""

    this.closeDropdown()

    // 下流コントローラに「新規登録モード」を通知
    document.dispatchEvent(new CustomEvent("brand:new", {
      detail: { brandName: this.inputTarget.value.trim() }
    }))
  }

  // 銘柄がクリアされたことを通知（下流コントローラ向け）
  dispatchBrandCleared() {
    document.dispatchEvent(new CustomEvent("brand:cleared", { detail: {} }))
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
