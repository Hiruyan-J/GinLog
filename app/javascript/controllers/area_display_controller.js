import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="area-display"
// 都道府県表示コントローラ
// brand / brewery コントローラのイベントを listen し、
// 都道府県の input(readonly) / select の切り替えを行う

// 状態パターン:
// - 初期（未選択）: input(readonly, 空) を表示、select は非活性・非表示
// - 銘柄選択 / 蔵元選択: input(readonly) に都道府県名を表示
// - 蔵元手入力モード: select を活性化し、都道府県を選択できるようにする
export default class extends Controller {
  static targets = [
    "input",        // 都道府県 input (readonly 表示用)
    "select"        // 都道府県 select (手入力モード時に活性化)
  ]

  static values = {
    initialBrandId: Number,       // 編集時の初期 brand_id
    initialBreweryId: Number,     // 編集時の初期 brewery_id
    initialAreaId: Number,        // 編集時の初期 area_id（蔵元手入力時）
    initialAreaName: String,      // 編集時の初期都道府県名
    manualBreweryMode: Boolean    // 蔵元手入力モードかどうか（バリデーションエラー時の select 復元に使用）
  }

  connect() {
    // brand / brewery コントローラからのイベントを listen
    this.boundOnBrandSelected = this.onBrandSelected.bind(this)
    this.boundOnBrandNew = this.onBrandNew.bind(this)
    this.boundOnBrandCleared = this.onBrandCleared.bind(this)
    this.boundOnBrewerySelected = this.onBrewerySelected.bind(this)
    this.boundOnBreweryNew = this.onBreweryNew.bind(this)
    this.boundOnBreweryCleared = this.onBreweryCleared.bind(this)

    document.addEventListener("brand:selected", this.boundOnBrandSelected)
    document.addEventListener("brand:new", this.boundOnBrandNew)
    document.addEventListener("brand:cleared", this.boundOnBrandCleared)
    document.addEventListener("brewery:selected", this.boundOnBrewerySelected)
    document.addEventListener("brewery:new", this.boundOnBreweryNew)
    document.addEventListener("brewery:cleared", this.boundOnBreweryCleared)

    this.restoreInitialValues()
  }

  disconnect() {
    document.removeEventListener("brand:selected", this.boundOnBrandSelected)
    document.removeEventListener("brand:new", this.boundOnBrandNew)
    document.removeEventListener("brand:cleared", this.boundOnBrandCleared)
    document.removeEventListener("brewery:selected", this.boundOnBrewerySelected)
    document.removeEventListener("brewery:new", this.boundOnBreweryNew)
    document.removeEventListener("brewery:cleared", this.boundOnBreweryCleared)
  }

  // 編集時や再表示時の初期状態を復元
  restoreInitialValues() {
    if (this.initialBrandIdValue > 0 || this.initialBreweryIdValue > 0) {
      // 銘柄選択済み or 蔵元選択済み → input(readonly) に都道府県名を表示
      this.showInput(this.initialAreaNameValue || "")
    } else if (this.initialAreaIdValue > 0 || this.manualBreweryModeValue) {
      // 蔵元手入力モード（バリデーションエラー再表示時など）→ select を活性化
      this.showSelect()
    } else {
      // 初期状態: input を非活性・空で表示
      this.showInput("")
    }
  }

  // --- イベントハンドラ ---
  onBrandSelected(event) {
    const { areaName } = event.detail
    this.showInput(areaName || "")
  }

  onBrandNew() {
    // 銘柄手入力モードに入った直後。蔵元はまだ未確定なので、都道府県も input を空で保持
    this.showInput("")
  }

  onBrandCleared() {
    // 銘柄がクリアされたら都道府県もリセット（input, 空）
    this.showInput("")
  }

  onBrewerySelected(event) {
    const { areaName } = event.detail
    this.showInput(areaName || "")
  }

  onBreweryNew() {
    // 蔵元手入力モードに入った → 都道府県を select に切り替え
    this.showSelect()
  }

  onBreweryCleared() {
    // 蔵元がクリアされた → 都道府県を input(空) に戻す
    this.showInput("")
  }

  // --- 表示切替 ---
  // input(readonly) を表示し、selectを非表示・非活性化
  showInput(areaName) {
    this.inputTarget.value = areaName
    this.inputTarget.classList.remove("hidden")

    this.selectTarget.classList.add("hidden")
    this.selectTarget.disabled = true
    this.selectTarget.value = ""
  }

  // selectを表示・活性化し、input(readonly)を非表示
  showSelect() {
    this.inputTarget.classList.add("hidden")
    this.inputTarget.value = ""

    this.selectTarget.classList.remove("hidden")
    this.selectTarget.disabled = false
  }
}
