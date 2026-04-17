#!/usr/bin/env bash
# 500-tx MsgSend burst across the 4 simd validators.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
N="${1:-500}"
SIMD="$HERE/vendor/simd"
BASE="$HERE/testnet"
OUT_DIR="$HERE/../artifacts/cosmos"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/run-$(date -u +%Y%m%dT%H%M%SZ).json"

# 4 validators, each has a wallet; we drive the burst from node0's
# keyring and round-robin the RPC endpoint used to submit.
RPCS=(26657 26647 26637 26627)

# Recipient = node1's validator account. Fetch its address deterministically.
TO=$("$SIMD" keys show node1 -a \
     --keyring-backend test --home "$BASE/node1/simd")

PY=$(mktemp)
cat > "$PY" <<'PY'
import json, os, sys, time, subprocess, urllib.request

SIMD = os.environ["SIMD"]
HOME = os.environ["NODE0_HOME"]
N = int(os.environ["N"])
TO = os.environ["TO"]
RPCS = os.environ["RPCS"].split(",")

def broadcast(rpc, i):
    # build + sign + broadcast in one shot using simd's tx mode=sync
    cmd = [
        SIMD, "tx", "bank", "send", "node0", TO, "1stake",
        "--chain-id", "bench-local",
        "--keyring-backend", "test",
        "--home", HOME,
        "--node", f"tcp://127.0.0.1:{rpc}",
        "--broadcast-mode", "sync",
        "--gas", "auto", "--gas-adjustment", "1.2",
        "--fees", "200stake",
        "--sequence", str(i),
        "--yes", "-o", "json",
    ]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        return False, r.stderr.strip().splitlines()[-1] if r.stderr else "error"
    try:
        resp = json.loads(r.stdout)
        return resp.get("code", 0) == 0, resp.get("raw_log", "")
    except json.JSONDecodeError:
        return False, r.stdout[:200]

latencies = []
start = time.time()
accepted = 0
for i in range(N):
    rpc = RPCS[i % len(RPCS)]
    t0 = time.time()
    ok, _ = broadcast(rpc, i)
    latencies.append((time.time() - t0) * 1000.0)
    if ok:
        accepted += 1

elapsed = (time.time() - start) * 1000.0
latencies.sort()

def pct(p):
    if not latencies: return 0
    idx = max(0, int(len(latencies) * p) - 1)
    return latencies[idx]

out = {
    "target": "cosmos",
    "consensus": "CometBFT",
    "version": os.environ.get("COSMOS_SDK_VERSION", "v0.50.9"),
    "cluster": {"nodes": 4, "location": "single-host-wsl2"},
    "workload": "transfer-500",
    "attempted": N,
    "accepted": accepted,
    "elapsed_ms": elapsed,
    "committed_tps": (accepted / elapsed) * 1000 if elapsed else 0,
    "p50_ms": pct(0.5),
    "p95_ms": pct(0.95),
    "p99_ms": pct(0.99),
    "started_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(start)),
    "notes": [
        "mode=sync; each broadcast is CheckTx only, not necessarily committed",
        "sequence is driven from the client; node0 wallet is the sender",
    ],
}
sys.stdout.write(json.dumps(out, indent=2))
PY

SIMD="$SIMD" NODE0_HOME="$BASE/node0/simd" N="$N" TO="$TO" \
RPCS="$(IFS=, ; echo "${RPCS[*]}")" COSMOS_SDK_VERSION="${COSMOS_SDK_VERSION:-v0.50.9}" \
python3 "$PY" > "$OUT"
rm -f "$PY"
echo "$OUT"
cat "$OUT"
