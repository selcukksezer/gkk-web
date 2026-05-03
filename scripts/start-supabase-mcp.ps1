$ErrorActionPreference = 'Stop'

$workspace = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $workspace '.env.local'

if (-not (Test-Path $envFile)) {
  Write-Error ".env.local not found at $envFile"
  exit 1
}

$envMap = @{}
Get-Content -Path $envFile | ForEach-Object {
  $line = $_.Trim()
  if ([string]::IsNullOrWhiteSpace($line)) { return }
  if ($line.StartsWith('#')) { return }

  $idx = $line.IndexOf('=')
  if ($idx -lt 1) { return }

  $key = $line.Substring(0, $idx).Trim()
  $value = $line.Substring($idx + 1).Trim()
  $envMap[$key] = $value
}

$baseUrl = $envMap['NEXT_PUBLIC_SUPABASE_URL']
$anonKey = $envMap['NEXT_PUBLIC_SUPABASE_ANON_KEY']

if (-not $baseUrl) {
  Write-Error 'NEXT_PUBLIC_SUPABASE_URL is missing in .env.local'
  exit 1
}

if (-not $anonKey) {
  Write-Error 'NEXT_PUBLIC_SUPABASE_ANON_KEY is missing in .env.local'
  exit 1
}

$apiUrl = "$baseUrl/rest/v1"

$npxArgs = @(
  '-y',
  '@supabase/mcp-server-postgrest',
  '--apiUrl', $apiUrl,
  '--apiKey', $anonKey,
  '--schema', 'public'
)

& npx @npxArgs
exit $LASTEXITCODE
