#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.pub-cache/bin:$PATH"

# Run analyzer; treat infos/warnings as errors by parsing output count
out=$(fvm flutter analyze || true)
echo "$out"

# Fail if output contains any issue lines
issues=$(echo "$out" | grep -E "^\s*[0-9]+\s+issues? found" || true)
if [[ -n "$issues" ]]; then
  # Extract counts summary line and check if 0 issues
  if ! echo "$issues" | grep -q "0 issues"; then
    echo "Analyzer reported issues: $issues" >&2
    exit 1
  fi
fi

echo "Analyzer passed with 0 issues"




