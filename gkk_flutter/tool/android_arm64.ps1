param(
    [ValidateSet("build-apk", "run")]
    [string]$Command = "build-apk",

    [ValidateSet("debug", "profile", "release")]
    [string]$BuildMode = "debug",

    [switch]$Clean
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

Push-Location $projectRoot
try {
    if ($Clean) {
        & flutter clean
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }

    $flutterArgs = switch ($Command) {
        "build-apk" { @("build", "apk") }
        "run" { @("run") }
    }

    $flutterArgs += "--$BuildMode"
    $flutterArgs += "--target-platform"
    $flutterArgs += "android-arm64"

    & flutter @flutterArgs
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}