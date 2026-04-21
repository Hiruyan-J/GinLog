import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="brewery-autocomplete"
// 銘柄手入力モード時に蔵元名を入力すると、既存の蔵元マスタから候補を表示する
// 候補選択時に都道府県を自動表示し、brewery_id をセットする
// 「該当する蔵元がない」を選択すると蔵元手入力モード（蔵元手入力 + 都道府県選択）に切り替わる
export default class extends Controller {
  static targets = [
    "input",
    "hiddenBreweryId",
    "dropdown",
    "areaDisplay",
    "areaSelect",       // 都道府県の select ボックス（蔵元手入力時に表示）
    "areaSelectWrapper" // 都道府県 select のラッパー(表示/非表示切り替え用)
  ]

  static values = {
    searchUrl: String,
    initialBreweryId: Number,     // 編集時の初期brewery_id
    initialBreweryName: String,   // 編集時の初期蔵元名
    initialAreaName: String       // 編集時の初期都道府県名
  }

  connect() {
    this.debounceTimer = null
    this.manualBreweryMode = false  // 蔵元手入力モードフラグ

    // プルダウン外クリック時にドロップダウンを閉じるためのリスナー
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
    if (this.initialBreweryIdValue && this.initialBreweryIdValue > 0) {
      this.hiddenBreweryIdTarget.value = this.initialBreweryIdValue
      this.inputTarget.value = this.initialBreweryNameValue
      this.showAreaDisplay(this.initialAreaNameValue)
    }
  }

  // 入力欄クリック時に入力済みテキストで検索
  onClick() {
    if (!this.dropdownTarget.classList.contains("hidden")) return
    // 蔵元手入力モード中はオートコンプリートしない
    if (this.manualBreweryMode) return

    const query = this.inputTarget.value.trim()
    if (query.length < 1) return

    this.searchBreweries(query)
  }

  // 入力欄のキー入力ハンドラ
  onInput() {
    clearTimeout(this.debounceTimer)
    const query = this.inputTarget.value.trim()

    // 蔵元手入力モード中はオートコンプリートしない
    if (this.manualBreweryMode) return

    // 入力が変わったらbrewery_idをクリア(再選択を促す)
    this.hiddenBreweryIdTarget.value = ""
    this.hideAreaDisplay()

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
      button.dataset.areaName = brewery.area_name
      button.textContent = brewery.label
      li.appendChild(button)
      ul.appendChild(li)
    })

    // 「該当する蔵元がない」オプションを追加
    if (query) {
      const newLi = document.createElement("li")
      const newButton = document.createElement("button")
      newButton.type = "button"
      newButton.className = "w-full text-left px-4 py-2 hover:bg-base-200 text-base-content/60 cursor-pointer"
      newButton.dataset.action = "click->brewery-autocomplete#selectManualBrewery"
      newButton.textContent = "該当する蔵元がない（手入力する）"
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
    const breweryId = button.dataset.breweryId
    const breweryName = button.dataset.breweryName
    const areaName = button.dataset.areaName

    // hidden フィールドにbrewery_idをセット
    this.hiddenBreweryIdTarget.value = breweryId
    // 入力欄に蔵元名表示
    this.inputTarget.value = breweryName
    // 都道府県を自動表示
    this.showAreaDisplay(areaName)
    this.hideAreaSelect()

    this.manualBreweryMode = false
    this.closeDropdown()
  }

  // 「該当する蔵元がない」を選択したとき → 蔵元手入力モードに切り替え
  selectManualBrewery() {
    this.manualBreweryMode = true
    // brewery_idをクリア
    this.hiddenBreweryIdTarget.value = ""

    // 都道府県の readonly表示を非表示にし、selectボックスを表示
    this.hideAreaDisplay()
    this.showAreaSelect()

    this.closeDropdown()
    this.inputTarget.focus()
  }

  // --- 都道府県表示の切り替え ---

  // 都道府県の読み取り専用フィールドに値をセットする
  showAreaDisplay(text) {
    this.areaDisplayTarget.value = text
    this.areaDisplayTarget.classList.remove("hidden")
  }

  // 都道府県の読み取り専用フィールドをクリアする
  hideAreaDisplay() {
    this.areaDisplayTarget.value = ""
    this.areaDisplayTarget.classList.add("hidden")
  }

  // 都道府県のselectボックスを表示する
  showAreaSelect() {
    this.areaSelectWrapperTarget.classList.remove("hidden")
  }

  // 都道府県のselectボックスを非表示にする
  hideAreaSelect() {
    this.areaSelectWrapperTarget.classList.add("hidden")
    this.areaSelectTarget.value = ""
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
