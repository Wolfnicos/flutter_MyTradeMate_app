#!/usr/bin/env bash
set -euo pipefail

echo "== Running red team tests =="
pushd "$(dirname "$0")/.." >/dev/null

flutter test --concurrency=1 --timeout=10s test/red_team

popd >/dev/null
echo "Done."




