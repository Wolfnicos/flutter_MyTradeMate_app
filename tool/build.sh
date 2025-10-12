#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.pub-cache/bin:$PATH"

# Android release build (Linux CI)
fvm flutter build apk --release

echo "APK built at build/app/outputs/flutter-apk/app-release.apk"







