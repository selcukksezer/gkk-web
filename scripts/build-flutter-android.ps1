# Build Flutter app with embedded Unity for Android

$ErrorActionPreference = "Stop"

$FlutterProjectPath = "F:\gkk-web\gkk_flutter"

Write-Host "Building Flutter app with Unity..." -ForegroundColor Green

# Check if flutter directory exists
if (-not (Test-Path $FlutterProjectPath)) {
    Write-Host "ERROR: Flutter project not found at: $FlutterProjectPath" -ForegroundColor Red
    exit 1
}

# Navigate to Flutter project
Push-Location $FlutterProjectPath

# Get dependencies
Write-Host "Getting Flutter dependencies..." -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Flutter pub get failed" -ForegroundColor Red
    Pop-Location
    exit 1
}

# Build APK for testing on Android
Write-Host "Building Android APK..." -ForegroundColor Cyan
flutter build apk --debug --dart-define=ENABLE_UNITY_WIDGET=true

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build successful!" -ForegroundColor Green
    $BuildOutput = "build\app\outputs\flutter-apk\app-debug.apk"
    if (Test-Path $BuildOutput) {
        $FileSize = (Get-Item $BuildOutput).Length / 1MB
        Write-Host "APK size: $([Math]::Round($FileSize, 2)) MB" -ForegroundColor Cyan
        Write-Host "Location: $BuildOutput" -ForegroundColor Cyan
    }
} else {
    Write-Host "ERROR: Build failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    Pop-Location
    exit 1
}

Pop-Location

Write-Host ""
Write-Host "Build complete!" -ForegroundColor Green
Write-Host "Run: flutter run --debug" -ForegroundColor Yellow
