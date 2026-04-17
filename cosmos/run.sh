#!/usr/bin/env bash
# Start the 4 simd validators in the background.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SIMD="$HERE/vendor/simd"
BASE="$HERE/testnet"
mkdir -p "$HERE/logs"

V=$(ls -d "$BASE"/node* 2>/dev/null | wc -l)
for i in $(seq 0 $((V - 1))); do
  "$SIMD" start --home "$BASE/node$i/simd" \
    > "$HERE/logs/node$i.out" 2>&1 &
  echo $! > "$HERE/logs/node$i.pid"
done

echo "$V simd validator(s) launched."
echo "tails: $HERE/logs/node*.out"
echo "RPC ports start at 26657"
sleep 3
python3 - <<'PY'
import json, sys, urllib.request
for i in range(4):
    port = 26657 - i*10
    try:
        d = json.loads(urllib.request.urlopen(f"http://127.0.0.1:{port}/status", timeout=2).read())
        print(f"node{i} block={d['result']['sync_info']['latest_block_height']}")
    except Exception as e:
        print(f"node{i} not ready yet ({e})")
PY
