import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="brewery-autocomplete"
// 銘柄手入力モード時に蔵元名を入力すると、既存の蔵元マスタから候補を表示する
// 候補選択時に都道府県を自動表示し、brewery_id をセットする
// 「該当する蔵元がない」を選択すると蔵元手入力モード（蔵元手入力 + 都道府県選択）に切り替わる
export default class extends Controller {
  static targets = [
    "input",
    "hiddenBreweryId",
    "dropdown"
  ]

  static values = {
    searchUrl: String,            // /api/breweries/search
    initialBrandId: Number,       // 編集時の初期 brand_id
    initialBreweryId: Number,     // 編集時の初期 brewery_id
    initialBreweryName: String    // 編集時の初期蔵元名
  }

  connect() {
    this.debounceTimer = null

    // プルダウン外クリック時にドロップダウンを閉じるためのリスナー
    this.boundHandleOutsideClick = this.handleOutsideClick.bind(this)
    document.addEventListener("click", this.boundHandleOutsideClick)

    // brand-autocompleteからのイベントを監視
    this.boundOnBrandSelected = this.onBrandSelected.bind(this)
    this.boundOnBrandNew = this.onBrandNew.bind(this)
    this.boundOnBrandCleared = this.onBrandCleared.bind(this)
    document.addEventListener("brand:selected", this.boundOnBrandSelected)
    document.addEventListener("brand:new", this.boundOnBrandNew)
    document.addEventListener("brand:cleared", this.boundOnBrandCleared)

    // 編集時: 初期値を復元
    this.restoreInitialValues()
  }

  disconnect() {
    document.removeEventListener("click", this.boundHandleOutsideClick)
    document.removeEventListener("brand:selected", this.boundOnBrandSelected)
    document.removeEventListener("brand:new", this.boundOnBrandNew)
    document.removeEventListener("brand:cleared", this.boundOnBrandCleared)
    clearTimeout(this.debounceTimer)
  }

  // 編集時に初期値を復元
  // - 銘柄選択済み(brand_id > 0): 蔵元名と brewery_id を復元、入力欄は非活性
  // - 銘柄手入力中 + 蔵元選択済み: 蔵元名と brewery_id を復元、入力欄は活性
  // - 銘柄手入力中 + 蔵元手入力: 蔵元名を復元、入力欄は活性
  // - 未入力: 入力欄は非活性
  restoreInitialValues() {
    if (this.initialBrandIdValue && this.initialBrandIdValue > 0) {
      // 銘柄選択済み
      this.inputTarget.value = this.initialBreweryNameValue
      this.hiddenBreweryIdTarget.value = this.initialBreweryIdValue || "" // brewery_id=0(無効な値)なら""を設定
      this.disableInput()
    } else if (this.initialBreweryIdValue && this.initialBreweryIdValue > 0) {
      // 銘柄手入力中 + 蔵元選択済み
      this.inputTarget.value = this.initialBreweryNameValue
      this.hiddenBreweryIdTarget.value = this.initialBreweryIdValue
      this.enableInput()
    } else if (this.initialBreweryNameValue) {
      // 銘柄手入力中 + 蔵元手入力
      this.inputTarget.value = this.initialBreweryNameValue
      this.hiddenBreweryIdTarget.value = ""
      this.enableInput()
    } else {
      // 未入力
      this.disableInput()
    }
  }

  // 銘柄選択時：蔵元を自動表示してreadonlyに
  onBrandSelected(event) {
    const { breweryId, breweryName } = event.detail
    this.inputTarget.value = breweryName || ""
    this.hiddenBreweryIdTarget.value = breweryId || ""
    this.disableInput()
    this.closeDropdown()
  }

  // 銘柄手入力時：蔵元をクリアして編集可能に
  onBrandNew() {
    this.inputTarget.value = ""
    this.hiddenBreweryIdTarget.value = ""
    this.enableInput()
    this.closeDropdown()
  }

  // 銘柄クリア時：蔵元をクリアしてreadonlyに
  onBrandCleared() {
    this.inputTarget.value = ""
    this.hiddenBreweryIdTarget.value = ""
    this.disableInput()
    this.closeDropdown()
    this.dispatchBreweryCleared()
  }

  // 入力欄クリック時に入力済みテキストで検索
  onClick() {
    if (this.inputTarget.disabled) return
    if (!this.dropdownTarget.classList.contains("hidden")) return

    const query = this.inputTarget.value.trim()
    if (query.length < 1) return

    this.searchBreweries(query)
  }

  // 入力欄のキー入力ハンドラ
  onInput() {
    if (this.inputTarget.disabled) return

    clearTimeout(this.debounceTimer)
    const query = this.inputTarget.value.trim()

    // 蔵元選択済みだった場合は、brewery:clearedを発火
    const hadSelectedBrewery = this.hiddenBreweryIdTarget.value !== ""
    this.hiddenBreweryIdTarget.value = ""

    if (hadSelectedBrewery) {
      this.dispatchBreweryCleared()
    }

    if (query.length < 1) {
      this.closeDropdown()
      return
    }

    // 300ms入力が止まったら検索
    this.debounceTimer = setTimeout(() => {
      this.searchBreweries(query)
    }, 300)
  }

  async searchBreweries(query) {
    try {
      const url = new URL(this.searchUrlValue, window.location.origin)
      url.searchParams.set("q", query)

      const response = await fetch(url, {
        headers: { "Accept": "application/json" },
        credentials: "same-origin"
      })

      if (!response.ok) return

      const data = await response.json()
      this.renderDropdown(data.breweries, query)
    } catch (error) {
      console.error("蔵元検索エラー:", error)
    }
  }

  // 候補リストの描画
  renderDropdown(breweries, query) {
    const ul = document.createElement("ul")
    ul.className = "flex flex-col bg-base-100 border border-base-300 rounded-box shadow-lg w-full max-h-60 overflow-y-auto list-none p-2"

    breweries.forEach(brewery => {
      const li = document.createElement("li")
      const button = document.createElement("button")
      button.type = "button"
      button.className = "w-full text-left px-4 py-2 hover:bg-base-200 cursor-pointer"
      button.dataset.action = "click->brewery-autocomplete#selectBrewery"
      button.dataset.breweryId = brewery.id
      button.dataset.breweryName = brewery.name
      button.dataset.areaId = brewery.area_id
      button.dataset.areaName = brewery.area_name
      button.textContent = brewery.label
      li.appendChild(button)
      ul.appendChild(li)
    })

    // 「新しい蔵元として登録」オプションを末尾に追加
    if (query) {
      const newLi = document.createElement("li")
      const newButton = document.createElement("button")
      newButton.type = "button"
      newButton.className = "w-full text-left px-4 py-2 hover:bg-base-200 text-base-content/60 cursor-pointer"
      newButton.dataset.action = "click->brewery-autocomplete#selectNewBrewery"
      newButton.textContent = "新しい蔵元として登録"
      newLi.appendChild(newButton)
      ul.appendChild(newLi)
    }

    this.dropdownTarget.innerHTML = ""
    this.dropdownTarget.appendChild(ul)
    this.dropdownTarget.classList.remove("hidden")
  }

  // 蔵元候補を選択したとき
  selectBrewery(event) {
    const button = event.currentTarget
    const breweryId = parseInt(button.dataset.breweryId, 10)
    const areaId = parseInt(button.dataset.areaId, 10)

    // hidden フィールドにbrewery_idをセット
    this.hiddenBreweryIdTarget.value = breweryId
    // 入力欄に蔵元名表示
    this.inputTarget.value = button.dataset.breweryName

    this.closeDropdown()

    document.dispatchEvent(new CustomEvent("brewery:selected", {
      detail: {
        breweryId,
        breweryName: button.dataset.breweryName,
        areaId,
        areaName: button.dataset.areaName
      }
    }))
  }

  // 「新しい蔵元として登録」を選択 → brewery:newを発火
  selectNewBrewery() {
    // brewery_idをクリア
    this.hiddenBreweryIdTarget.value = ""
    this.closeDropdown()

    document.dispatchEvent(new CustomEvent("brewery:new", {
      detail: { breweryName: this.inputTarget.value.trim() }
    }))
  }

  // 蔵元クリアを下流に通知
  dispatchBreweryCleared() {
    document.dispatchEvent(new CustomEvent("brewery:cleared", { detail: {} }))
  }

  // 入力欄を活性化
  enableInput() {
    this.inputTarget.disabled = false
    this.inputTarget.classList.remove("bg-base-200", "text-base-content/70")
    this.inputTarget.classList.add("input-primary")
  }

  // 入力欄を非活性化
  disableInput() {
    this.inputTarget.disabled = true
    this.inputTarget.classList.add("bg-base-200", "text-base-content/70")
    this.inputTarget.classList.remove("input-primary")
  }

  // --- ドロップダウン制御 ---
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
