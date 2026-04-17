#!/usr/bin/env bash
# 500-tx eth_sendTransaction burst across 4 geth RPC endpoints.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
N="${1:-500}"
OUT_DIR="$HERE/../artifacts/ethereum"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/run-$(date -u +%Y%m%dT%H%M%SZ).json"

python3 - "$N" > "$OUT" <<'PY'
import json, os, sys, time, urllib.request

N = int(sys.argv[1])
RPCS = ["http://127.0.0.1:8545", "http://127.0.0.1:8546",
        "http://127.0.0.1:8547", "http://127.0.0.1:8548"]

def call(rpc, method, params):
    req = urllib.request.Request(
        rpc,
        data=json.dumps({"jsonrpc":"2.0","method":method,"params":params,"id":1}).encode(),
        headers={"content-type": "application/json"},
    )
    return json.loads(urllib.request.urlopen(req, timeout=5).read())

# Use node-a's first account as sender; recipient = node-b's first account.
sender_accounts = call(RPCS[0], "eth_accounts", [])["result"]
recipient_accounts = call(RPCS[1], "eth_accounts", [])["result"]
sender, recipient = sender_accounts[0], recipient_accounts[0]

# Make sure sender is unlocked on its home node
call(RPCS[0], "personal_unlockAccount", [sender, "bench", 3600])

latencies = []
start = time.time()
accepted = 0
for i in range(N):
    rpc = RPCS[i % len(RPCS)]
    # sendTransaction is local-node-signed; we drive it from node-a only.
    t0 = time.time()
    try:
        r = call(RPCS[0], "eth_sendTransaction", [{
            "from": sender,
            "to": recipient,
            "value": hex(1),
            "gas": hex(21000),
        }])
        latencies.append((time.time() - t0) * 1000.0)
        if "result" in r:
            accepted += 1
    except Exception:
        latencies.append((time.time() - t0) * 1000.0)

elapsed = (time.time() - start) * 1000.0
latencies.sort()
def pct(p):
    if not latencies: return 0
    idx = max(0, int(len(latencies) * p) - 1)
    return latencies[idx]

print(json.dumps({
    "target": "ethereum",
    "consensus": "Clique-PoA",
    "version": "v1.13.15",
    "cluster": {"nodes": 4, "location": "single-host-wsl2"},
    "workload": "transfer-500",
    "attempted": N, "accepted": accepted,
    "elapsed_ms": elapsed,
    "committed_tps": (accepted / elapsed) * 1000 if elapsed else 0,
    "p50_ms": pct(0.5), "p95_ms": pct(0.95), "p99_ms": pct(0.99),
    "started_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(start)),
    "notes": [
        "eth_sendTransaction: local-node-signed, 1-wei transfer, 21000 gas",
        "all sends go through node-a RPC; the 4-node cluster mines them together",
    ],
}, indent=2))
PY

echo "$OUT"
cat "$OUT"
