#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$HERE/validator.pid" ]; then
  kill "$(cat "$HERE/validator.pid")" 2>/dev/null || true
  rm -f "$HERE/validator.pid"
fi
rm -rf "$HERE/ledger"
echo "solana-test-validator stopped"
