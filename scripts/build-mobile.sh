#!/usr/bin/env bash
# ============================================================
# build-mobile.sh — Build & sync for Capacitor mobile platforms
# ============================================================

set -euo pipefail

echo "🔨 Building Next.js static export..."
npm run build

echo ""
echo "📱 Syncing with Capacitor..."
npx cap sync

# Optional: Open native IDE
if [[ "${1:-}" == "android" ]]; then
  echo "🤖 Opening Android Studio..."
  npx cap open android
elif [[ "${1:-}" == "ios" ]]; then
  echo "🍎 Opening Xcode..."
  npx cap open ios
else
  echo ""
  echo "✅ Build & sync complete."
  echo "   Run: npx cap open android   — to open Android Studio"
  echo "   Run: npx cap open ios        — to open Xcode"
fi
