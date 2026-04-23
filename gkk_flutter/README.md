# gkk_flutter

A new Flutter project.

## Android arm64 commands

Use the PowerShell wrapper below so Flutter always builds or runs with android-arm64:

```powershell
pwsh -File .\tool\android_arm64.ps1 -Command build-apk -BuildMode debug
pwsh -File .\tool\android_arm64.ps1 -Command run -BuildMode debug
```

Workspace tasks are also available in VS Code:

- Flutter Build APK Arm64 Debug
- Flutter Build APK Arm64 Release
- Flutter Run Arm64 Debug

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
