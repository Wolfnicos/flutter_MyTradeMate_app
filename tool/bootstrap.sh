#!/usr/bin/env bash
set -euo pipefail

# Ensure fvm is available; if not, install globally via pub
if ! command -v fvm >/dev/null 2>&1; then
  dart pub global activate fvm >/dev/null
  export PATH="$HOME/.pub-cache/bin:$PATH"
fi

# Install Flutter SDK via fvm
fvm install
fvm flutter --version

# Get dependencies
fvm flutter pub get

echo "Bootstrap complete"




