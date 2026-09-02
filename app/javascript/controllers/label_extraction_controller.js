import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="label-extraction"
export default class extends Controller {
  static targets = [
    "button",              // 「ラベルを読み取る」ボタン
    "buttonLabel",         // ボタンの文言（読み取り中…に切り替える）
    "spinner",             // ローディングスピナー
    "message",             // 結果・エラーメッセージの表示枠
    "remaining",           // 「本日あと◯回」の表示
    "brandCandidates",     // 銘柄候補リストの表示枠
    "breweryCandidates",   // 蔵元候補リストの表示枠
    "productAlternatives"  // 商品名の別候補チップの表示枠
  ]

  static values = {
    url: String,       // POST /api/label_extraction
    remaining: Number  // 本日の残り実行可能回数
  }

  // 送信前に画像を縮小するときの長辺の上限(px)
  // 読み取り精度が低い場合は 2000 まで上げて精度を確認する
  static MAX_DIMENSION = 1000

  connect() {
    this.loading = false
  }

  // remainingValue が変わるたびに表示を更新する（Stimulusのvalue変更コールバック）
  remainingValueChanged() {
    if (this.hasRemainingTarget) {
      this.remainingTarget.textContent = `本日あと${this.remainingValue}回`
    }
  }

  // 「ラベルを読み取る」ボタン押下
  async extract() {
    if (this.loading) return

    const frontFile = this.findImageFile("front_label_image")
    const backFile = this.findImageFile("back_label_image")
    if (!frontFile && !backFile) {
      this.showMessage("表ラベルまたは裏ラベルの写真を選択してから実行してください", "warning")
      return
    }
    if (this.remainingValue <= 0) {
      this.showMessage("本日の利用回数の上限に達しました。明日また利用できます", "warning")
      return
    }

    this.setLoading(true)
    this.clearResults()
    try {
      const formData = new FormData()
      if (frontFile) {
        formData.append("front_label_image", await this.resizeImage(frontFile), "front_label.jpg")
      }
      if (backFile) {
        formData.append("back_label_image", await this.resizeImage(backFile), "back_label.jpg")
      }

      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          "Accept": "application/json"
        },
        body: formData,
        credentials: "same-origin"
      })
      const data = await response.json()

      if (!response.ok) {
        this.showMessage(data.error || "読み取りに失敗しました。時間をおいて再度お試しください", "error")
        return
      }
      this.applyResult(data)
    } catch (error) {
      console.error("AIラベル読み取りエラー:", error)
      this.showMessage("通信に失敗しました。時間をおいて再度お試しください", "error")
    } finally {
      this.setLoading(false)
    }
  }

  // --- 結果のフォーム反映 ---

  // 読み取り結果をフォーム全体へ反映する
  applyResult(data) {
    const extraction = data.extraction
    this.remainingValue = data.remaining_count

    if (!extraction.brand_name && !extraction.product_name && !extraction.brewery_name) {
      this.showMessage("ラベルから情報を読み取れませんでした。お手数ですが手動で入力してください", "warning")
      return
    }

    this.applyBrand(extraction, data)
    this.applyProductName(extraction)

    if (extraction.confidence === "low") {
      this.showMessage("読み取りの確度が低めです。内容をよく確認してください", "warning")
    } else if (data.brand_match.status === "multiple") {
      this.showMessage("銘柄の候補が複数見つかりました。正しいものを選んでください", "info")
    } else if (data.brand_match.status === "none" && data.brewery_match.status === "multiple") {
      this.showMessage("同じ名前の蔵元が複数あります。正しいものを選んでください", "info")
    } else {
      this.showMessage("読み取りました。内容を確認してから登録してください", "success")
    }
  }

  // 銘柄の照合結果に応じてフォームへ反映する
  //   1件一致   → 自動で選択状態にする
  //   複数一致   → 候補チップを表示してユーザーに選ばせる
  //   一致なし   → 手入力モードとして反映（蔵元・都道府県も埋める）
  applyBrand(extraction, data) {
    const match = data.brand_match
    if (match.status === "single") {
      this.selectBrand(match.candidates[0])
    } else if (match.status === "multiple") {
      this.setFieldValue("sake_log_manual_brand_name", extraction.brand_name)
      this.setFieldValue("sake_log_brand_id", "")
      document.dispatchEvent(new CustomEvent("brand:new", { detail: { brandName: extraction.brand_name } }))
      this.renderBrandCandidates(match.candidates)
    } else if (extraction.brand_name) {
      this.applyManualBrand(extraction, data)
    }
  }

  // マスタと一致した銘柄をフォームへ反映する
  // （オートコンプリートで候補を選択したときと同じ状態を作る）
  selectBrand(candidate) {
    this.setFieldValue("sake_log_brand_id", candidate.id)
    this.setFieldValue("sake_log_manual_brand_name", candidate.name)
    document.dispatchEvent(new CustomEvent("brand:selected", {
      detail: {
        brandId: candidate.id,
        brandName: candidate.name,
        breweryId: candidate.brewery_id,
        breweryName: candidate.brewery_name,
        areaId: candidate.area_id,
        areaName: candidate.area_name
      }
    }))
  }

  // 銘柄がマスタにない場合: 手入力モードとして反映し、蔵元・都道府県も埋める
  applyManualBrand(extraction, data) {
    this.setFieldValue("sake_log_manual_brand_name", extraction.brand_name)
    this.setFieldValue("sake_log_brand_id", "")
    document.dispatchEvent(new CustomEvent("brand:new", { detail: { brandName: extraction.brand_name } }))

    const match = data.brewery_match
    if (match.status === "single") {
      // 蔵元はマスタにあった → 選択状態にする
      this.selectBrewery(match.candidates[0])
    } else if (match.status === "multiple") {
      // 同名の蔵元が複数ある（例: 吉田酒造は5県に存在）→ ユーザーに選ばせる
      // ここで都道府県を自動セットしないのは、AIが酒米の産地を都道府県として
      // 読んでしまう誤りが実測されているため。候補から選べば正しい県が入る
      this.setFieldValue("sake_log_manual_brewery_name", extraction.brewery_name)
      this.setFieldValue("sake_log_brewery_id", "")
      document.dispatchEvent(new CustomEvent("brewery:new", { detail: { breweryName: extraction.brewery_name } }))
      this.renderBreweryCandidates(match.candidates)
    } else if (extraction.brewery_name) {
      // 蔵元もマスタにない → 蔵元手入力モードにして読み取り値を入れる
      this.setFieldValue("sake_log_manual_brewery_name", extraction.brewery_name)
      this.setFieldValue("sake_log_brewery_id", "")
      document.dispatchEvent(new CustomEvent("brewery:new", { detail: { breweryName: extraction.brewery_name } }))
      // 都道府県はマスタと一致したときだけ select にセットする
      if (data.area) {
        this.setFieldValue("sake_log_area_id", data.area.id)
      }
    }
  }

  // マスタと一致した蔵元をフォームへ反映する
  // （蔵元オートコンプリートで候補を選択したときと同じ状態を作る）
  selectBrewery(candidate) {
    this.setFieldValue("sake_log_manual_brewery_name", candidate.name)
    this.setFieldValue("sake_log_brewery_id", candidate.id)
    document.dispatchEvent(new CustomEvent("brewery:selected", {
      detail: {
        breweryId: candidate.id,
        breweryName: candidate.name,
        areaId: candidate.area_id,
        areaName: candidate.area_name
      }
    }))
  }

  // 商品名（第1候補）を入力欄へ反映し、別候補があればチップを表示する
  applyProductName(extraction) {
    if (extraction.product_name) {
      this.setFieldValue("sake_log_product_name", extraction.product_name)
      // AIが入れた商品名は既存Sakeの選択ではないため sake_id はクリアする
      this.setFieldValue("sake_log_sake_id", "")
    }
    if (extraction.product_name_alternatives?.length > 0) {
      this.renderProductAlternatives(extraction.product_name_alternatives)
    }
  }

  // --- 候補チップの描画 ---

  // 候補リストを描画する（銘柄・蔵元で共通）
  // 取り違えると他の人の集計まで巻き込むため、小さなチップではなく
  // 既存のオートコンプリートと同じ「全幅の行」にしてタップ領域を確保する
  // 並び順はサーバー側で確度の高い順に整えてある
  // @param target 描画先の要素
  // @param headingText 見出しの文言
  // @param candidates 候補の配列（確度の高い順）
  // @param actionName クリック時に呼ぶアクション名
  renderCandidateList(target, headingText, candidates, actionName) {
    const wrapper = document.createElement("div")
    wrapper.className = "flex flex-col gap-1"

    const heading = document.createElement("span")
    heading.className = "text-xs text-base-content/70"
    heading.textContent = headingText
    wrapper.appendChild(heading)

    const ul = document.createElement("ul")
    ul.className = "flex flex-col bg-base-100 border border-base-300 rounded-box shadow-lg w-full max-h-60 overflow-y-auto list-none p-2"
    candidates.forEach(candidate => {
      const li = document.createElement("li")
      const button = document.createElement("button")
      button.type = "button"
      button.className = "w-full text-left px-4 py-2 hover:bg-base-200 cursor-pointer"
      button.dataset.action = `click->label-extraction#${actionName}`
      // 候補をまるごとJSONで持たせる（項目ごとに data 属性を並べなくて済む）
      button.dataset.candidate = JSON.stringify(candidate)
      button.textContent = candidate.label
      li.appendChild(button)
      ul.appendChild(li)
    })
    wrapper.appendChild(ul)

    target.innerHTML = ""
    target.appendChild(wrapper)
    target.classList.remove("hidden")
  }

  // 銘柄候補を描画する
  renderBrandCandidates(candidates) {
    this.renderCandidateList(
      this.brandCandidatesTarget, "銘柄の候補（上ほど確からしい順）:", candidates, "selectBrandCandidate"
    )
  }

  // 蔵元候補を描画する
  renderBreweryCandidates(candidates) {
    this.renderCandidateList(
      this.breweryCandidatesTarget, "蔵元の候補（上ほど確からしい順）:", candidates, "selectBreweryCandidate"
    )
  }

  // 銘柄候補を選択したとき
  selectBrandCandidate(event) {
    this.selectBrand(JSON.parse(event.currentTarget.dataset.candidate))
    this.brandCandidatesTarget.classList.add("hidden")
    this.showMessage("銘柄を反映しました。内容を確認してから登録してください", "success")
  }

  // 蔵元候補を選択したとき
  selectBreweryCandidate(event) {
    this.selectBrewery(JSON.parse(event.currentTarget.dataset.candidate))
    this.breweryCandidatesTarget.classList.add("hidden")
    this.showMessage("蔵元を反映しました。内容を確認してから登録してください", "success")
  }

  // 商品名の別候補チップを描画する
  renderProductAlternatives(alternatives) {
    const wrapper = this.buildChipsWrapper("商品名の別候補:")
    alternatives.forEach(name => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "btn btn-outline btn-primary btn-xs"
      button.dataset.action = "click->label-extraction#selectProductAlternative"
      button.dataset.productName = name
      button.textContent = name
      wrapper.appendChild(button)
    })

    this.productAlternativesTarget.innerHTML = ""
    this.productAlternativesTarget.appendChild(wrapper)
    this.productAlternativesTarget.classList.remove("hidden")
  }

  // 商品名の別候補チップを選択したとき（チップは残して選び直せるようにする）
  selectProductAlternative(event) {
    this.setFieldValue("sake_log_product_name", event.currentTarget.dataset.productName)
    this.setFieldValue("sake_log_sake_id", "")
  }

  // チップの入れ物（見出し + flexコンテナ）を作る
  buildChipsWrapper(labelText) {
    const wrapper = document.createElement("div")
    wrapper.className = "flex flex-wrap gap-1 items-center"
    const label = document.createElement("span")
    label.className = "text-xs text-base-content/70"
    label.textContent = labelText
    wrapper.appendChild(label)
    return wrapper
  }

  // --- 画像・フォームまわりのヘルパー ---

  // フォーム内のファイル入力から選択済みのファイルを取得する
  // （ファイル入力は image_field パーシャル内にあるため、name属性で探す）
  findImageFile(attachmentName) {
    const input = this.element
      .closest("form")
      .querySelector(`input[type="file"][name="sake_log[${attachmentName}]"]`)
    return input?.files[0] || null
  }

  // 画像を長辺 MAX_DIMENSION px 以下に縮小してJPEGに変換する
  // API送信量とトークン数を抑えるため。縮小に失敗した場合
  // （HEICなどブラウザが描画できない形式）は元ファイルのまま返す
  async resizeImage(file) {
    try {
      // EXIFの回転情報を反映してデコードする（スマホ写真の向き対策）
      const bitmap = await createImageBitmap(file, { imageOrientation: "from-image" })
      const maxDimension = this.constructor.MAX_DIMENSION
      const scale = Math.min(1, maxDimension / Math.max(bitmap.width, bitmap.height))
      if (scale >= 1) return file

      const canvas = document.createElement("canvas")
      canvas.width = Math.round(bitmap.width * scale)
      canvas.height = Math.round(bitmap.height * scale)
      canvas.getContext("2d").drawImage(bitmap, 0, 0, canvas.width, canvas.height)

      const blob = await new Promise(resolve => canvas.toBlob(resolve, "image/jpeg", 0.85))
      return blob || file
    } catch {
      return file
    }
  }

  // Railsのform_withが生成するID（sake_log_brand_id など）で入力欄に値をセットする
  setFieldValue(id, value) {
    const field = document.getElementById(id)
    if (field) field.value = value
  }

  // --- 表示制御 ---

  // ローディング状態の切り替え（二重送信防止を兼ねる）
  setLoading(loading) {
    this.loading = loading
    this.buttonTarget.disabled = loading
    this.spinnerTarget.classList.toggle("hidden", !loading)
    this.buttonLabelTarget.textContent = loading ? "読み取り中…" : "ラベルを読み取る"
  }

  // メッセージを表示する（type: "success" | "info" | "warning" | "error"）
  showMessage(text, type) {
    this.messageTarget.textContent = text
    this.messageTarget.className = `alert alert-${type} text-sm`
  }

  // 前回の結果表示をすべて消す
  clearResults() {
    this.messageTarget.className = "hidden"
    this.messageTarget.textContent = ""
    this.brandCandidatesTarget.classList.add("hidden")
    this.brandCandidatesTarget.innerHTML = ""
    this.breweryCandidatesTarget.classList.add("hidden")
    this.breweryCandidatesTarget.innerHTML = ""
    this.productAlternativesTarget.classList.add("hidden")
    this.productAlternativesTarget.innerHTML = ""
  }
}
