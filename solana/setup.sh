#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

if ! command -v solana >/dev/null; then
  sh -c "$(curl -sSfL https://release.solana.com/v1.18.26/install)"
  export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
fi

mkdir -p "$HERE/ledger"
solana-test-validator --ledger "$HERE/ledger" --reset --quiet \
  > "$HERE/validator.log" 2>&1 &
echo $! > "$HERE/validator.pid"
echo "solana-test-validator launched (pid $(cat "$HERE/validator.pid"))"
sleep 5
solana cluster-version --url http://127.0.0.1:8899
