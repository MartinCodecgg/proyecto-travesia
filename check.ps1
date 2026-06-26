$content = Get-Content -Raw scripts/tablero_principal.html
$opens = ($content.ToCharArray() | Where-Object {$_ -eq '{'}).Count
$closes = ($content.ToCharArray() | Where-Object {$_ -eq '}'}).Count
Write-Host "Opens: $opens"
Write-Host "Closes: $closes"
$diff = $opens - $closes
Write-Host "Diff: $diff"
