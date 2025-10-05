#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.pub-cache/bin:$PATH"

# Ensure repo root
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

# Use FVM when available
if command -v fvm >/dev/null 2>&1; then
  FLUTTER="fvm flutter"
else
  FLUTTER="flutter"
fi

mkdir -p coverage

# Fail if any test files remain in test/_skipped/
if find test/_skipped -type f -name "*_test.dart" 2>/dev/null | grep -q .; then
  echo "ERROR: Found *_test.dart inside test/_skipped. Rename to *.SKIP.dart."
  exit 1
fi

echo "=== Diagnostic: test files enumeration ==="
# Ignore tests under test/_skipped/ (portable across older macOS bash)
TEST_FILES=$(find test -type f -name "*_test.dart" ! -path "test/_skipped/*" | sort || true)
COUNT=$(printf "%s\n" "$TEST_FILES" | grep -c "_test.dart" || true)
echo "Found test files: ${COUNT}"
printf "%s\n" "$TEST_FILES" | nl | sed -n '1,200p'
echo "========================================="

# MIN_EXPECTED hard guard (anti-empty suite)
MIN_EXPECTED="${MIN_EXPECTED:-50}"
if [ "${COUNT:-0}" -lt "$MIN_EXPECTED" ]; then
  echo "ERROR: Only ${COUNT} *_test.dart discovered (min ${MIN_EXPECTED})."
  exit 1
fi

RUN_FIRST_FAIL=${RUN_FIRST_FAIL:-1}
if [ "${RUN_PER_FILE:-0}" = "1" ]; then
  echo "=== Per-file test mode (debug) ==="
  set -o pipefail
  while IFS= read -r f; do
    echo ">>> RUN $f"
    if ! $FLUTTER test --reporter expanded --concurrency=1 "$f" 2>&1 | tee ".testlog.$(basename "$f").log"; then
      echo "!!! FAILED: $f"
      [ "$RUN_FIRST_FAIL" = "1" ] && exit 1
    fi
  done <<EOF
$TEST_FILES
EOF
  exit 0
fi

echo "=== Running full, filtered test suite (excluding test/_skipped) ==="
# Discovery mode: do NOT pass file list; rely on .SKIP/.env guards for exclusions
$FLUTTER test \
  --coverage \
  --reporter expanded \
  --concurrency=1 \
  --test-randomize-ordering-seed=random

STATUS=$?
echo "flutter test exit status: $STATUS"
if [ $STATUS -ne 0 ]; then
  exit $STATUS
fi

if [[ ! -f coverage/lcov.info ]]; then
  echo "coverage/lcov.info missing" >&2
  exit 1
fi

# ----- Cleaned-core coverage (robust) -----
set -e

if ! command -v lcov >/dev/null 2>&1; then
  echo "WARN: 'lcov' absent => folosesc coverage/lcov.info ca fallback"
  cp coverage/lcov.info coverage/lcov.cleaned.info
else
  # Stabilim ROOT relativ la locația scriptului (portabil) și fișierele LCOV
  ROOT="$(cd "$(dirname "$0")/.."; pwd)"
  LCOV_RAW="coverage/lcov.info"
  LCOV_CLEAN="coverage/lcov.cleaned.info"

  # (opțional) diagnostic rapid
  RAW_SF=$(grep -c '^SF:' "$LCOV_RAW" || true)
  echo "lcov raw SF entries: $RAW_SF"

  # Normalizează căile la absolute dacă apar relative în lcov.info
  if grep -q '^SF:lib/' "$LCOV_RAW"; then
    sed -i.bak "s|^SF:lib/|SF:${ROOT}/lib/|g" "$LCOV_RAW"
  fi

  # Curăță pe core (căi absolute!), tolerează empty/unused; macOS lcov nu înțelege **
  lcov --quiet --extract "$LCOV_RAW" \
    "${ROOT}/lib/services/*" \
    "${ROOT}/lib/src/core/*" \
    "${ROOT}/lib/models/*" \
    --ignore-errors unused,empty \
    --output-file "$LCOV_CLEAN"

  # Fallback robust: dacă extract-ul a produs 0 fișiere, filtrează manual pe SF:
  LF=$(lcov --summary "$LCOV_CLEAN" 2>/dev/null | awk '/lines\.*:/ {print $2}' | cut -d/ -f2)
  if [ -z "$LF" ] || [ "$LF" -eq 0 ]; then
    echo "lcov extract matched 0 files — falling back to manual filter"
    awk -v keep=0 '
      /^SF:/ {
        path=$0
        keep = (path ~ /\/lib\/services\/|\/lib\/src\/core\/|\/lib\/models\//)
        if (keep) print
        next
      }
      /^end_of_record/ { if (keep) print; next }
      { if (keep) print }
    ' "$LCOV_RAW" > "$LCOV_CLEAN"
  fi
fi

# (4) Rezumat + poartă STRICTĂ (eșuează dacă LF=0)
SUMMARY=$(lcov --summary coverage/lcov.cleaned.info 2>/dev/null || true)
LINE_SUM=$(echo "$SUMMARY" | grep -E 'lines\.*:' || true)
PAIR=$(echo "$LINE_SUM" | grep -Eo '[0-9]+ of [0-9]+' | head -n1 || true)

if [ -n "$PAIR" ]; then
  LH=$(echo "$PAIR" | awk '{print $1}')
  LF=$(echo "$PAIR" | awk '{print $3}')
else
  # Fallback to summing LH/LF tags if summary format not as expected
  LH=$(grep -Eo 'LH:[0-9]+' coverage/lcov.cleaned.info | awk -F: '{s+=$2} END{print s+0}')
  LF=$(grep -Eo 'LF:[0-9]+' coverage/lcov.cleaned.info | awk -F: '{s+=$2} END{print s+0}')
fi

PCT=$(awk -v lh="$LH" -v lf="$LF" 'BEGIN{ if(lf==0){print 0}else{printf "%.2f", (lh*100.0/lf)} }')

echo "Coverage (cleaned core): ${PCT}% (${LH}/${LF})"

: "${COVERAGE_GATE:=60}"
if [ -z "$LF" ] || [ "$LF" -eq 0 ]; then
  echo "FAIL: cleaned-core trace is empty (LF=0). Fix extract patterns or tests before gating."
  exit 1
fi

NEEDED=$(awk -v lf="$LF" -v gate="$COVERAGE_GATE" 'BEGIN{ printf "%d", (gate*lf+99)/100 }')
if [ "$LH" -lt "$NEEDED" ]; then
  echo "FAIL: coverage ${PCT}% < gate ${COVERAGE_GATE}% (${LH}/${LF} < ${NEEDED}/${LF})"
  exit 1
fi

