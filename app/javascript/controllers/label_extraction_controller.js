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
    "productCandidates"    // 商品名候補リストの表示枠
  ]

  static values = {
    url: String,        // POST /api/label_extraction
    remaining: Number,  // 本日の残り実行可能回数
    dailyLimit: Number  // 1日の上限回数（LabelExtractionLog::DAILY_LIMIT）
  }

  // 送信前に画像を縮小するときの長辺の上限(px)
  static MAX_DIMENSION = 1000

  // サーバーの応答を待つ上限(ミリ秒)
  // サーバー側は「本命モデル30秒 + 退避モデル30秒」で最長60秒かかりうるため、
  // 画像アップロードとRailsの処理ぶんの余裕を足した値にする。
  // サーバーが応答を返せない状態（プロセス停止など）でも、
  // ここで打ち切られるのでボタンが押せないままにならない
  static REQUEST_TIMEOUT_MS = 75000

  // AIが値を入れた入力欄に付ける背景色
  static AUTO_FILLED_CLASS = "bg-info/30"

  // 選択中の候補に付ける背景色
  // 候補一覧を消さずに残すようにしたため、どれを選んだのかを色で示す
  static SELECTED_CANDIDATE_CLASS = "bg-primary/20"

  connect() {
    this.loading = false
    this.autoFilledFields = new Set()
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
      this.showMessage(this.limitReachedMessage(), "error")
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
        credentials: "same-origin",
        // この時間を過ぎたら通信を中断する（TimeoutError が throw される）
        signal: AbortSignal.timeout(this.constructor.REQUEST_TIMEOUT_MS)
      })
      const data = await response.json()

      if (!response.ok) {
        // サーバーは Gemini を呼ぶ前に実行回数を記録するため、
        // 読み取りに失敗した場合も1回消費されている。
        // エラー応答に含まれる残り回数で表示を合わせる
        this.applyRemainingCount(data)
        this.showMessage(data.error || "読み取りに失敗しました。時間をおいて再度お試しください", "error")
        return
      }
      this.applyResult(data)
    } catch (error) {
      console.error("AIラベル読み取りエラー:", error)
      // AbortSignal.timeout() による中断は TimeoutError として飛んでくる。
      // 通信自体ができなかった場合と原因が違うため、メッセージを分ける
      if (error.name === "TimeoutError") {
        // 応答は受け取れなくてもサーバー側で実行可能回数が減っている為1減らす
        this.remainingValue = Math.max(0, this.remainingValue - 1)
        this.showMessage("読み取りに時間がかかりすぎました。時間をおいて再度お試しください", "error")
      } else {
        // 送信自体が失敗した場合は消費されたか分からないため、表示は変えない
        this.showMessage("通信に失敗しました。時間をおいて再度お試しください", "error")
      }
    } finally {
      this.setLoading(false)
    }
  }

  // 上限に達したときのメッセージ
  // サーバー側の Api::LabelExtractionsController#create と同じ文言にすること
  limitReachedMessage() {
    return `本日のAI読み取りの利用上限（${this.dailyLimitValue}回）に達しました。明日また利用できます`
  }

  // --- 結果のフォーム反映 ---

  // サーバーが返した残り回数を表示へ反映する
  // 成功・失敗のどちらの応答にも含まれる。
  applyRemainingCount(data) {
    if (typeof data.remaining_count === "number") {
      this.remainingValue = data.remaining_count
    }
  }

  // 読み取り結果をフォーム全体へ反映する
  applyResult(data) {
    const extraction = data.extraction
    this.applyRemainingCount(data)

    if (!extraction.brand_name && !extraction.product_name && !extraction.brewery_name) {
      this.showMessage("ラベルから情報を読み取れませんでした。お手数ですが手動で入力してください", "warning")
      return
    }

    this.applyBrand(extraction, data)
    const productCandidates = this.applyProductName(extraction, data)

    if (extraction.confidence === "low") {
      this.showMessage("読み取りの確度が低めです。内容をよく確認してください", "warning")
    } else if (data.brand_match.status === "multiple") {
      this.showMessage("銘柄の候補が複数見つかりました。正しいものを選んでください", "info")
    } else if (data.brand_match.status === "none" && data.brewery_match.status === "multiple") {
      this.showMessage("同じ名前の蔵元が複数あります。正しいものを選んでください", "info")
    } else if (data.brewery_brands?.length > 0) {
      // 蔵元だけ確定したケース。同じ銘柄を二重に登録しないよう選択を促す
      this.showMessage("吟ログにある銘柄と一致しませんでした。同じ蔵元の銘柄から選ぶこともできます", "info")
    } else if (productCandidates.length > 1 && data.brand_sakes?.length > 0) {
      // 銘柄が確定したケース。同じ商品を二重に登録しないよう選択を促す
      // 候補が1件のときは一覧を出していないので案内もしない。
      // AIが登録済みの商品名をそのまま読めた場合がこれにあたり、
      // 保存時に既存レコードへ紐づくので利用者に選ばせる必要がない
      this.showMessage("この銘柄には記録済みの商品名があります。同じ商品なら候補から選んでください", "info")
    } else {
      this.showMessage("読み取りました。内容を確認してから登録してください", "success")
    }
  }

  // 銘柄の照合結果に応じてフォームへ反映する
  //   1件一致   → 自動で選択状態にする（蔵元・都道府県も一緒に決まる）
  //   複数一致   → 候補リストを表示してユーザーに選ばせる
  //   一致なし   → 銘柄は手入力モードにし、蔵元を別に反映する
  applyBrand(extraction, data) {
    const match = data.brand_match
    if (match.status === "single") {
      this.selectBrand(match.candidates[0])
      return
    }

    if (match.status === "multiple") {
      this.startManualBrand(extraction.brand_name)
      this.renderBrandCandidates(match.candidates, extraction.brand_name)
      return
    }

    this.startManualBrand(extraction.brand_name)
    this.applyBrewery(extraction, data)
  }

  // 銘柄を手入力モードへ切り替える
  //
  // 銘柄名を読み取れなかった場合（brandName が null）も必ず呼ぶこと。
  // 蔵元・商品名の入力欄は brand:selected / brand:new を受け取って
  // はじめて入力できる状態になるため、ここを通さないと
  // 読み取った蔵元をセットしても入力欄が disabled のままになり、
  // フォームの送信対象から外れてしまう。
  //
  // @param brandName 読み取った銘柄名（読み取れなかった場合は null）
  startManualBrand(brandName) {
    this.setFieldValue("sake_log_brand_id", "")
    // 読み取れなかったときは、利用者がすでに入力した銘柄名を空で上書きしない
    if (brandName) this.setAutoFilledValue("sake_log_manual_brand_name", brandName)
    document.dispatchEvent(new CustomEvent("brand:new", { detail: { brandName: brandName || "" } }))
  }

  // マスタと一致した銘柄をフォームへ反映する
  // （オートコンプリートで候補を選択したときと同じ状態を作る）
  selectBrand(candidate) {
    this.setFieldValue("sake_log_brand_id", candidate.id)
    this.setAutoFilledValue("sake_log_manual_brand_name", candidate.name)
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

  // 蔵元の照合結果に応じてフォームへ反映する。銘柄が確定しなかったときだけ呼ばれる
  //   1件一致   → 選択状態にし、必要ならその蔵元の銘柄一覧を出す
  //   複数一致   → 蔵元候補リストを表示してユーザーに選ばせる
  //   一致なし   → 蔵元手入力モードにして読み取り値を入れる
  applyBrewery(extraction, data) {
    const match = data.brewery_match
    if (match.status === "single") {
      // 蔵元はマスタにあった → 選択状態にする
      this.selectBrewery(match.candidates[0])
      // 蔵元は確定したのに銘柄がマスタに無い場合、その蔵元の銘柄から選べるようにする。
      // 「HIRAN」のようにラベル通りに読むとマスタ（飛鸞）と一致しないことがあり、
      // そのまま登録すると同じ銘柄が2つできてしまうため
      if (data.brewery_brands?.length > 0) {
        this.renderBreweryBrands(data.brewery_brands, match.candidates[0].name, extraction.brand_name)
      }
    } else if (match.status === "multiple") {
      // 同名の蔵元が複数ある（例: 吉田酒造は5県に存在）→ ユーザーに選ばせる
      // ここで都道府県を自動セットしないのは、AIが酒米の産地を都道府県として
      // 読んでしまう誤りが実測されているため。候補から選べば正しい県が入る
      this.setAutoFilledValue("sake_log_manual_brewery_name", extraction.brewery_name)
      this.setFieldValue("sake_log_brewery_id", "")
      document.dispatchEvent(new CustomEvent("brewery:new", { detail: { breweryName: extraction.brewery_name } }))
      this.renderBreweryCandidates(match.candidates)
    } else if (extraction.brewery_name) {
      // 蔵元もマスタにない → 蔵元手入力モードにして読み取り値を入れる
      this.setAutoFilledValue("sake_log_manual_brewery_name", extraction.brewery_name)
      this.setFieldValue("sake_log_brewery_id", "")
      document.dispatchEvent(new CustomEvent("brewery:new", { detail: { breweryName: extraction.brewery_name } }))
      // 都道府県はマスタと一致したときだけ select にセットする
      if (data.area) {
        this.setAutoFilledValue("sake_log_area_id", data.area.id)
      }
    }
  }

  // マスタと一致した蔵元をフォームへ反映する
  // （蔵元オートコンプリートで候補を選択したときと同じ状態を作る）
  selectBrewery(candidate) {
    this.setAutoFilledValue("sake_log_manual_brewery_name", candidate.name)
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

  // 商品名を入力欄へ反映し、候補が2つ以上あれば一覧を表示する
  applyProductName(extraction, data) {
    if (extraction.product_name) {
      this.setAutoFilledValue("sake_log_product_name", extraction.product_name)
      // AIが入れた商品名は既存Sakeの選択ではないため sake_id はクリアする
      this.setFieldValue("sake_log_sake_id", "")
    }

    // 登録済みの商品名を先頭に置く（選んでほしいのはこちらのため）
    const registered = data.brand_sakes || []
    const registeredNames = new Set(registered.map(sake => sake.product_name))
    // AIの読み取りは第1候補を先頭に置く（読み取れなかった値と、登録済みと同じ文字列は除く）
    const readNames = [ extraction.product_name, ...(extraction.product_name_alternatives || []) ]
      .filter(name => name && !registeredNames.has(name))
    const suffix = registered.length > 0 ? "（新しい商品として登録）" : ""
    const candidates = [
      ...registered,
      ...readNames.map(name => ({ label: `${name}${suffix}`, product_name: name }))
    ]

    // 候補が1つだけなら選ぶ余地がないので一覧は出さない
    if (candidates.length > 1) this.renderProductCandidates(candidates)

    return candidates
  }

  // --- 候補リストの描画 ---

  // 候補リストを描画する（銘柄・蔵元・商品名で共通）
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
  // @param candidates マスタの銘柄候補
  // @param brandName AIが読み取った銘柄名
  renderBrandCandidates(candidates, brandName) {
    this.renderCandidateList(
      this.brandCandidatesTarget, "銘柄の候補（上ほど確からしい順）:",
      this.withReadBrand(candidates, brandName), "selectBrandCandidate"
    )
  }

  // 蔵元候補を描画する
  renderBreweryCandidates(candidates) {
    this.renderCandidateList(
      this.breweryCandidatesTarget, "蔵元の候補（上ほど確からしい順）:", candidates, "selectBreweryCandidate"
    )
  }

  // 確定した蔵元が持つ銘柄の一覧を描画する
  // 選んだあとの挙動は通常の銘柄候補と同じなので、描画先とアクションを共用する
  // @param candidates その蔵元のマスタ銘柄
  // @param breweryName 見出しに出す蔵元名
  // @param brandName AIが読み取った銘柄名
  renderBreweryBrands(candidates, breweryName, brandName) {
    this.renderCandidateList(
      this.brandCandidatesTarget, `${breweryName} の銘柄から選ぶ:`,
      this.withReadBrand(candidates, brandName), "selectBrandCandidate"
    )
  }

  // マスタの銘柄候補の末尾に「読み取った名前のまま新しく登録する」選択肢を足す
  //
  // これが無いと、候補を押し間違えたときに読み取った銘柄名へ戻す手段がない。
  // マスタの候補は id を持つので、id が無いことが「マスタに無い銘柄」の目印になる
  // （selectBrandCandidate はこれを見て分岐する）。
  //
  // @param candidates マスタの銘柄候補
  // @param brandName AIが読み取った銘柄名（読み取れなかった場合は null）
  // @return 候補の配列
  withReadBrand(candidates, brandName) {
    if (!brandName) return candidates

    return [ ...candidates, { name: brandName, label: `${brandName}（新しい銘柄として登録）` } ]
  }

  // 商品名の候補を描画する
  // 登録済み（sake_id つき）とAIの読み取り（文字列だけ）が混ざるため、
  // 候補の形に揃える役目は呼び出し側にて行う
  // @param candidates 商品名候補の配列（登録済みが先頭）
  renderProductCandidates(candidates) {
    this.renderCandidateList(
      this.productCandidatesTarget, "商品名の候補:", candidates, "selectProductCandidate"
    )
  }

  // --- 候補の選択 ---

  // 銘柄候補を選択したとき
  selectBrandCandidate(event) {
    const candidate = JSON.parse(event.currentTarget.dataset.candidate)
    if (candidate.id) {
      this.selectBrand(candidate)
      this.showMessage("銘柄を反映しました。違っていれば候補から選び直せます", "success")
    } else {
      // 蔵元・都道府県は brand:new を受け取っても消えないので、そのまま残る
      this.startManualBrand(candidate.name)
      this.showMessage("読み取った銘柄名に戻しました。新しい銘柄として登録されます", "info")
    }
    this.markSelectedCandidate(event.currentTarget)
  }

  // 蔵元候補を選択したとき
  selectBreweryCandidate(event) {
    this.selectBrewery(JSON.parse(event.currentTarget.dataset.candidate))
    this.markSelectedCandidate(event.currentTarget)
    this.showMessage("蔵元を反映しました。違っていれば候補から選び直せます", "success")
  }

  // 商品名候補を選択したとき
  selectProductCandidate(event) {
    const candidate = JSON.parse(event.currentTarget.dataset.candidate)
    this.setAutoFilledValue("sake_log_product_name", candidate.product_name)
    // 登録済みの商品を選んだときだけ sake_id を立てて既存レコードへ紐づける。
    // AIの読み取りを選んだ場合は sake_id を持たないので、ここでクリアされる
    this.setFieldValue("sake_log_sake_id", candidate.sake_id || "")
    this.markSelectedCandidate(event.currentTarget)
  }

  // 選択中の候補に色を付ける
  // 一覧を消さずに残すようにしたため、色が無いとどれを選んだのか分からなくなる。
  // 同じ一覧の中の他の候補からは色を外す（選択は常に1つ）
  // @param button 押された候補のボタン要素
  markSelectedCandidate(button) {
    const selectedClass = this.constructor.SELECTED_CANDIDATE_CLASS
    button.closest("ul").querySelectorAll("button").forEach(other => {
      other.classList.remove(selectedClass, "font-semibold")
    })
    button.classList.add(selectedClass, "font-semibold")
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

  // 値をセットしたうえで「AIが入れた欄」と分かるよう背景色を付ける
  //
  // hidden フィールド（brand_id など）には使わないこと。見えない欄に色を付けても
  // 意味がないうえ、利用者が直接編集できないので色を消す機会が無い。
  //
  // @param id 入力欄のID
  // @param value セットする値
  setAutoFilledValue(id, value) {
    const field = document.getElementById(id)
    if (!field) return

    field.value = value
    field.classList.add(this.constructor.AUTO_FILLED_CLASS)
    this.autoFilledFields.add(field)
    // 利用者が手で直した時点でAIの入力ではなくなるため、最初の入力で色を消す。
    // once を付けているので、色を消したあとはこのリスナー自体も外れる
    field.addEventListener("input", () => this.unmarkAutoFilled(field), { once: true })
  }

  // 「AIが入力した」背景色を消す
  unmarkAutoFilled(field) {
    field.classList.remove(this.constructor.AUTO_FILLED_CLASS)
    this.autoFilledFields.delete(field)
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
    this.productCandidatesTarget.classList.add("hidden")
    this.productCandidatesTarget.innerHTML = ""
    // 前回AIが入れた欄の色を戻す。読み取り直しの結果と混ざらないようにするため
    // （Set を回しながら消すので、いったん配列にコピーしてから処理する）
    Array.from(this.autoFilledFields).forEach(field => this.unmarkAutoFilled(field))
  }
}
