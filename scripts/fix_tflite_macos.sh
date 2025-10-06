#!/usr/bin/env bash
set -euo pipefail

APP_NAME="mytrademate"
BUILD_DIR="build/macos/Build/Products/Debug"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
FW_DIR="${APP_PATH}/Contents/Frameworks"
RES_DIR="${APP_PATH}/Contents/Resources"

echo "[1/6] Build debug macOS…"
flutter build macos --debug >/dev/null

if [ ! -d "${APP_PATH}" ]; then
  echo "Eroare: nu găsesc ${APP_PATH} după build." >&2
  exit 1
fi

echo "[2/6] Caut libtensorflowlite_c-mac.dylib în ~/.pub-cache…"
SRC="$(find "${HOME}/.pub-cache/hosted/pub.dev" -name 'libtensorflowlite_c-mac.dylib' -print -quit || true)"
if [ -z "${SRC}" ] || [ ! -f "${SRC}" ]; then
  echo "Eroare: nu am găsit libtensorflowlite_c-mac.dylib în cache. Rulează 'flutter pub get' și reîncearcă." >&2
  exit 1
fi
echo "Găsit: ${SRC}"

echo "[3/6] Copiez în bundle (Frameworks + Resources)…"
mkdir -p "${FW_DIR}" "${RES_DIR}"
/bin/cp -f "${SRC}" "${FW_DIR}/libtensorflowlite_c.dylib"
/bin/cp -f "${SRC}" "${RES_DIR}/libtensorflowlite_c-mac.dylib"

echo "[4/6] Elimin quarantine (dacă există)…"
/usr/bin/xattr -dr com.apple.quarantine "${FW_DIR}/libtensorflowlite_c.dylib" 2>/dev/null || true
/usr/bin/xattr -dr com.apple.quarantine "${RES_DIR}/libtensorflowlite_c-mac.dylib" 2>/dev/null || true
/usr/bin/xattr -dr com.apple.quarantine "${APP_PATH}" 2>/dev/null || true

echo "[5/6] Codesign dylib-urile și aplicația…"
/usr/bin/codesign --force --deep -s - "${FW_DIR}/libtensorflowlite_c.dylib"
/usr/bin/codesign --force --deep -s - "${RES_DIR}/libtensorflowlite_c-mac.dylib"
/usr/bin/codesign --force --deep -s - "${APP_PATH}"

echo "[6/6] Verific fișierele în bundle…"
ls -lh "${FW_DIR}/libtensorflowlite_c.dylib"
ls -lh "${RES_DIR}/libtensorflowlite_c-mac.dylib"

echo "✅ Fix aplicat. Pornesc aplicația…"
open "${APP_PATH}"
