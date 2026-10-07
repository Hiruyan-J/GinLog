// 画像を長辺 maxDimension px 以下に縮小してJPEGに変換する
// 縮小が不要な場合と、縮小に失敗した場合
// （HEICなどブラウザが描画できない形式）は元ファイルのまま返す
export async function resizeImage(file, maxDimension) {
  let bitmap
  try {
    // EXIFの回転情報を反映してデコードする（スマホ写真の向き対策）
    bitmap = await createImageBitmap(file, { imageOrientation: "from-image" })
    const scale = Math.min(1, maxDimension / Math.max(bitmap.width, bitmap.height)) // 拡大防止
    if (scale >= 1) return file

    const canvas = document.createElement("canvas")
    canvas.width = Math.round(bitmap.width * scale)
    canvas.height = Math.round(bitmap.height * scale)
    const context = canvas.getContext("2d")
    // JPEGは透過を持てず透過部分が黒くなるため、先に白で塗る
    context.fillStyle = "#fff"
    context.fillRect(0, 0, canvas.width, canvas.height)
    context.drawImage(bitmap, 0, 0, canvas.width, canvas.height)  // canvasへの描画

    const blob = await new Promise(resolve => canvas.toBlob(resolve, "image/jpeg", 0.85))
    if (!blob) return file
    return new File([blob], jpegFileName(file.name), { type: "image/jpeg" })
  } catch {
    return file
  } finally {
    // デコード済みの画像はメモリを大きく使うため、使い終わったら解放する
    bitmap?.close()
  }
}

// ファイル名の拡張子を .jpg に付け替える（例: label.png → label.jpg）
function jpegFileName(name) {
  return `${name.replace(/\.[^.]+$/, "")}.jpg`
}
