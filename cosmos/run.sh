#!/usr/bin/env bash
# Start the 4 simd validators in the background.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SIMD="$HERE/vendor/simd"
BASE="$HERE/testnet"
mkdir -p "$HERE/logs"

for i in 0 1 2 3; do
  "$SIMD" start --home "$BASE/node$i/simd" \
    > "$HERE/logs/node$i.out" 2>&1 &
  echo $! > "$HERE/logs/node$i.pid"
done

echo "4 simd validators launched."
echo "tails: $HERE/logs/node*.out"
echo "RPC ports: 26657, 26647, 26637, 26627"
sleep 3
for i in 0 1 2 3; do
  curl -sS "http://127.0.0.1:$((26657 - i*10))/status" | \
    python3 -c 'import sys,json; d=json.load(sys.stdin); r=d["result"]["sync_info"]; print(f"node{sys.argv[1]} block {r[\"latest_block_height\"]}")' "$i" \
    || echo "node$i not ready yet"
done
