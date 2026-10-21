param([int]$Port = 8765, [string]$Root = $PSScriptRoot)

# このPCの中だけで使う簡易Webサーバー (localhost のみ。外部からは接続できない)
# Windows 標準の HttpListener を使う。接続の管理は Windows 側が行うため、
# ブラウザが同時に複数の接続を開いても止まらない。

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving at http://localhost:$Port/  (このウィンドウを閉じると終了します)"

$mime = @{
  ".html" = "text/html; charset=utf-8"; ".js" = "text/javascript"; ".mjs" = "text/javascript"; ".css" = "text/css"
  ".png" = "image/png"; ".jpg" = "image/jpeg"; ".svg" = "image/svg+xml"
  ".json" = "application/json"; ".wasm" = "application/wasm"; ".ico" = "image/x-icon"
}
$rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $res = $ctx.Response
  try {
    $path = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath)
    if ($path -eq '/') { $path = '/index.html' }
    $full = [System.IO.Path]::GetFullPath((Join-Path $rootFull ($path.TrimStart('/') -replace '/', '\')))
    # フォルダの外のファイルは返さない
    if ($full.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $full -PathType Leaf)) {
      $bytes = [System.IO.File]::ReadAllBytes($full)
      $ext = [System.IO.Path]::GetExtension($full).ToLower()
      $res.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { "application/octet-stream" }
    } else {
      $res.StatusCode = 404
      $res.ContentType = "text/plain"
      $bytes = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
    }
    $res.ContentLength64 = $bytes.Length
    $res.OutputStream.Write($bytes, 0, $bytes.Length)
  } catch {
  } finally {
    try { $res.Close() } catch {}
  }
}
