#!/usr/bin/env bash
set -euo pipefail

SCHEME="Runner"
CONFIG="Release"
ARCHIVE_PATH="build/ios/archive/Runner.xcarchive"
EXPORT_DIR="build/ios/export"

echo "== iOS release build =="$CONFIG" =="
pushd "$(dirname "$0")/.." >/dev/null

mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_DIR"

flutter --version
flutter clean
flutter pub get

echo "-- Build iOS (no codesign) --"
flutter build ios --release --no-codesign

echo "-- Archive via xcodebuild --"
xcodebuild -workspace ios/Runner.xcworkspace \
  -scheme "$SCHEME" -configuration "$CONFIG" \
  -archivePath "$ARCHIVE_PATH" archive

if [[ -f ios/ExportOptions.plist ]]; then
  echo "-- Export signed IPA using ExportOptions.plist --"
  xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" -exportOptionsPlist ios/ExportOptions.plist
  echo "Exported IPA(s):"
  ls -lh "$EXPORT_DIR"/*.ipa || true
else
  echo "Unsigned archive at $ARCHIVE_PATH (ExportOptions.plist not provided)"
fi

popd >/dev/null
echo "Done."


