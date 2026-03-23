# Doğrudan DB'deki items sayısını kontrol et
$dump = Get-Content -Raw -Path .\itemvarolan.sql
$items = [regex]::Matches($dump, "'((?:res_|scroll_|catalyst_|potion_|han_item_|rune_|resource_)[a-zA-Z0-9_]+)'") | % { $_.Groups[1].Value } | Sort-Object -Unique

# Kategori bazında sayım
$by_cat = $items | Group-Object { 
  if ($_ -like 'res_*') { 'res' }
  elseif ($_ -like 'scroll*') { 'scroll' }
  elseif ($_ -like 'catalyst*') { 'catalyst' }
  elseif ($_ -like 'potion*') { 'potion' }
  elseif ($_ -like 'han_item*') { 'han_item' }
  elseif ($_ -like 'rune*') { 'rune' }
  elseif ($_ -like 'resource*') { 'monument' }
  else { 'other' }
} | Sort-Object Name

Write-Output "=== DB'deki TOPLAM ITEM SAYISI ==="
Write-Output "Toplam: "($items |  Measure-Object | % Count)
Write-Output ""
Write-Output "=== KATEGOR BAZINDA ==="
$by_cat | ForEach-Object { 
  Write-Output "$($_.Name): $($_.Count) item"
}
