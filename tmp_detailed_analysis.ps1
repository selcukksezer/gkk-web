$ErrorActionPreference = 'Stop'
$root = Get-Location

# === PLAN BEKLENTLER ===
$planFiles = Get-ChildItem -Path $root -Filter 'PLAN_*.md' | Sort-Object Name
$planText = ($planFiles | ForEach-Object { Get-Content -Raw -Path $_.FullName }) -join "`n"

# 1. Backtick içindeki ID'leri çıkar
$regex = [regex]'`(res_[a-z0-9_]+|scroll_[a-z0-9_]+|catalyst_[a-z0-9_]+|potion_[a-z0-9_]+|han_item_[a-z0-9_]+|resource_(?:structural|mystical|critical))`'
$expected = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($m in $regex.Matches($planText)) { [void]$expected.Add($m.Groups[1].Value) }

# 2. Semantik: PLAN_05'ten rune ID'leri
@('rune_basic','rune_advanced','rune_superior','rune_legendary','rune_protection','rune_blessed') | ForEach-Object { [void]$expected.Add($_) }

# 3. PLAN_10'tan monument resource'lar
@('resource_structural','resource_mystical','resource_critical') | ForEach-Object { [void]$expected.Add($_) }

Write-Output "=== PLAN BEKLENTLER ==="
Write-Output "Toplam beklenen: $($expected.Count)"
Write-Output ""

# === DB MEVCUT DURUMU ===
$dump = Get-Content -Raw -Path (Join-Path $root 'itemvarolan.sql')
$actual = New-Object 'System.Collections.Generic.HashSet[string]'
$actualRegex = [regex]"'((?:res_|scroll_|catalyst_|potion_|han_item_|rune_|resource_)[a-z0-9_]+)'"
foreach ($m in $actualRegex.Matches($dump)) { [void]$actual.Add($m.Groups[1].Value) }

Write-Output "=== DB MEVCUT DURUMU ==="
Write-Output "Toplam mevcut: $($actual.Count)"
Write-Output ""

# === FARK ANALZ ===
$missing = @($expected | Where-Object { $_ -notin $actual } | Sort-Object)
$extra = @($actual | Where-Object { $_ -notin $expected } | Sort-Object)

Write-Output "=== FARK ==="
Write-Output "Eksik: $($missing.Count)"
Write-Output "Fazla: $($extra.Count)"
Write-Output ""

if ($missing.Count -gt 0) {
  Write-Output "=== EKSK TEMLER (PLAN'de var, DB'de yok) ==="
  $missing | ForEach-Object { Write-Output "  - $_" }
}
Write-Output ""

if ($extra.Count -gt 0) {
  Write-Output "=== FAZLA TEMLER (DB'de var, PLAN'de yok) ==="
  $extra | ForEach-Object { Write-Output "  - $_" }
}
