# Kleiner lokaler Webserver fuer docs/ (nur localhost), z.B. fuer die Regionen-Kontrollkarte
param([int]$Port = 8765)
$root = Join-Path $PSScriptRoot '..\docs' | Resolve-Path
$l = New-Object System.Net.HttpListener
$l.Prefixes.Add("http://localhost:$Port/")
$l.Start()
Write-Output "docs-server laeuft auf http://localhost:$Port/"
while ($l.IsListening) {
  $c = $l.GetContext()
  $p = [Uri]::UnescapeDataString($c.Request.Url.AbsolutePath.TrimStart('/'))
  if (-not $p) { $p = 'regionen-vorschlag.html' }
  $f = Join-Path $root $p
  if ((Test-Path $f -PathType Leaf) -and ((Resolve-Path $f).Path.StartsWith($root.Path))) {
    $b = [IO.File]::ReadAllBytes($f)
    $c.Response.ContentType = if ($f -like '*.html') { 'text/html; charset=utf-8' } elseif ($f -like '*.js') { 'text/javascript; charset=utf-8' } else { 'application/octet-stream' }
    $c.Response.OutputStream.Write($b, 0, $b.Length)
  } else { $c.Response.StatusCode = 404 }
  $c.Response.Close()
}
