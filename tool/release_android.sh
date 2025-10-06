#!/usr/bin/env bash
set -euo pipefail

echo "== Android release build (AAB/APK) =="
pushd "$(dirname "$0")/.." >/dev/null

# Optional signing guard: set SIGNING_REQUIRED=1 to enforce env presence
SIGNING_REQUIRED="${SIGNING_REQUIRED:-0}"
if [[ "$SIGNING_REQUIRED" == "1" ]]; then
  : "${ANDROID_KEYSTORE:?ANDROID_KEYSTORE not set}"
  : "${ANDROID_KEY_ALIAS:?ANDROID_KEY_ALIAS not set}"
  : "${ANDROID_KEYSTORE_PASSWORD:?ANDROID_KEYSTORE_PASSWORD not set}"
  : "${ANDROID_KEY_PASSWORD:?ANDROID_KEY_PASSWORD not set}"
fi

# Optional Play track (for future upload steps)
PLAY_TRACK="${PLAY_TRACK:-}"

# Derive version from pubspec.yaml (name+code)
PUBVER=$(grep -E '^version:' pubspec.yaml | awk '{print $2}') || PUBVER=""
VERSION_NAME="${VERSION_NAME:-${PUBVER%%+*}}"
VERSION_CODE_ENV="${VERSION_CODE:-}"
if [[ -z "$VERSION_CODE_ENV" ]]; then
  # Fallback to unix epoch seconds for deterministic monotonic code
  VERSION_CODE_ENV=$(date +%s)
fi
echo "VERSION_NAME=$VERSION_NAME VERSION_CODE=$VERSION_CODE_ENV"

flutter --version
flutter clean
flutter pub get

echo "-- Build AAB --"
flutter build appbundle --release

echo "-- Build APK --"
flutter build apk --release

echo "Artifacts:"
AAB="build/app/outputs/bundle/release/app-release.aab"
APK_GLOB="build/app/outputs/flutter-apk/*release*.apk"

ls -lh "$AAB" 2>/dev/null || true
ls -lh $APK_GLOB 2>/dev/null || true

if [[ ! -f "$AAB" ]]; then
  echo "ERROR: Missing AAB artifact at $AAB" >&2
  exit 2
fi
APK_FOUND=$(ls $APK_GLOB 2>/dev/null | head -n1 || true)
if [[ -z "$APK_FOUND" ]]; then
  echo "ERROR: Missing APK artifact in $APK_GLOB" >&2
  exit 3
fi

echo "Done."
popd >/dev/null


