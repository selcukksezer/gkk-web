# Android APK Build & Tablet Testing Guide

## Build Status
- Build started: `flutter build apk --debug --dart-define=ENABLE_UNITY_WIDGET=true`
- Currently compiling IL2CPP code and packaging APK
- Estimated time: 10-15 minutes depending on hardware

## Once Build Completes

### Step 1: Locate the APK
The built APK will be at:
```
F:\gkk-web\gkk_flutter\build\app\outputs\flutter-apk\app-debug.apk
```

### Step 2: Transfer to Tablet
#### Option A: Using `flutter run` (Automatic)
```powershell
cd F:\gkk-web\gkk_flutter
flutter run --debug
```
This will automatically:
1. Build the APK
2. Install on connected Android device
3. Launch the app
4. Show hot-reload console

#### Option B: Manual Transfer
1. Connect tablet via USB
2. Copy APK to tablet
3. Open file manager on tablet and install

### Step 3: Test the Character
1. Launch GKK Mobile app on tablet
2. Login (or skip if auto-login works)
3. Navigate to Character Select screen
4. Verify:
   - Character **faces camera** (not rotated sideways)
   - **Texture is visible** (not pure white or stretched)
   - **Drag to rotate** works smoothly on screen

### Step 4: Troubleshooting
If character appears stretched or rotated:
- Check that file changes were saved properly
- Rebuild with clean: `flutter clean && flutter build apk --debug --dart-define=ENABLE_UNITY_WIDGET=true`

If texture is missing:
- Check that `FrostboundRanger_Albedo.png` and `FrostboundRanger_Normal.png` are in Resources folder
- Verify .meta files have correct import settings

## Changes Made in This Build
1. **Character Orientation**: Rotation constant changed from -8° to 0° (face camera directly)
2. **Texture Import**: Normal map set to linear color space (was incorrectly in sRGB)
3. **Android Build**: Cleaned IL2CPP cache to prevent duplicate symbol errors
