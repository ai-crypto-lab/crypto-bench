#!/usr/bin/env bash
# 500-tx PaymentTransaction burst against algod dev-mode.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
N="${1:-500}"
OUT_DIR="$HERE/../artifacts/algorand"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/run-$(date -u +%Y%m%dT%H%M%SZ).json"

TOKEN="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
ALGOD="http://127.0.0.1:4001"

# Inside the container, goal has a default wallet that owns the
# dev-mode genesis allocation. We fetch two addresses — sender and
# recipient — and use goal to issue transfers.
docker exec algobench-algod /node/bin/goal wallet list \
  -d /algod/data >/dev/null

python3 - "$N" "$TOKEN" "$ALGOD" > "$OUT" <<'PY'
import json, subprocess, sys, time

N = int(sys.argv[1])

def goal(*args):
    return subprocess.run(
        ["docker", "exec", "algobench-algod", "/node/bin/goal", *args,
         "-d", "/algod/data"],
        capture_output=True, text=True,
    )

# Get two accounts from the default wallet
accounts = [line.split()[1]
            for line in goal("account", "list").stdout.splitlines()
            if line.startswith("[") and len(line.split()) >= 2]
if len(accounts) < 2:
    # Create a recipient if missing
    new = goal("account", "new").stdout
    accounts.append(new.split()[-1])
sender, recipient = accounts[0], accounts[1]

latencies = []
start = time.time()
accepted = 0
for i in range(N):
    t0 = time.time()
    # `goal clerk send` without `--out` signs + broadcasts in one call;
    # dev-mode commits the block on demand after receipt.
    r = goal("clerk", "send",
             "-a", "1",
             "-f", sender, "-t", recipient)
    if r.returncode == 0 and "Sent " in r.stdout:
        accepted += 1
    latencies.append((time.time() - t0) * 1000.0)

elapsed = (time.time() - start) * 1000.0
latencies.sort()
pct = lambda p: latencies[max(0, int(len(latencies) * p) - 1)] if latencies else 0
print(json.dumps({
    "target": "algorand",
    "consensus": "BA* PureProofOfStake (dev-mode single node)",
    "version": "stable-3.24+",
    "cluster": {"nodes": 1, "location": "single-host-wsl2"},
    "workload": "transfer-500",
    "attempted": N, "accepted": accepted,
    "elapsed_ms": elapsed,
    "committed_tps": (accepted / elapsed) * 1000 if elapsed else 0,
    "p50_ms": pct(0.5), "p95_ms": pct(0.95), "p99_ms": pct(0.99),
    "started_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(start)),
    "notes": [
        "dev-mode issues blocks on demand; not a multi-validator network",
        "acceptance = goal clerk rawsend succeeded; confirmation lag not measured",
    ],
}, indent=2))
PY

echo "$OUT"
cat "$OUT"
