#!/usr/bin/env bash
# 500-tx PaymentTransaction burst against algod dev-mode.
#
# Runs the submit loop *inside* the algobench-algod container via a
# single `docker exec`, amortizing the docker exec startup cost
# (~400-900 ms per invocation on WSL2) across the whole burst. That
# turns out to be the dominant overhead vs. a per-tx invocation.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
N="${1:-500}"
OUT_DIR="$HERE/../artifacts/algorand"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/run-$(date -u +%Y%m%dT%H%M%SZ).json"

# Pick two accounts from the default wallet.
mapfile -t ADDRS < <(docker exec algobench-algod goal account list -d /algod/data \
  | grep -oE "[A-Z2-7]{58}" | awk '!seen[$0]++')
FROM="${ADDRS[0]}"
TO="${ADDRS[1]:-${ADDRS[0]}}"
if [ "$FROM" = "$TO" ] && [ "${#ADDRS[@]}" -gt 1 ]; then
  TO="${ADDRS[1]}"
fi

STARTED=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Run the burst inside the container. For each tx we record nanosecond
# start + end timestamps so we can compute per-tx latency. `goal` does
# sign + broadcast; in dev-mode this commits the block inline.
RAW=$(docker exec algobench-algod bash -c "
  set -u
  accepted=0
  latencies=()
  for i in \$(seq 1 $N); do
    t0=\$(date +%s%N)
    if goal clerk send -a 1 -f $FROM -t $TO -d /algod/data > /dev/null 2>&1; then
      accepted=\$((accepted+1))
    fi
    t1=\$(date +%s%N)
    latencies+=(\$((t1 - t0)))
  done
  echo \"ACCEPTED \$accepted\"
  for l in \"\${latencies[@]}\"; do echo \"LAT \$l\"; done
")

# Parse the raw output in Python (with stdlib json + statistics).
python3 - "$N" "$STARTED" <<PY > "$OUT"
import json, sys, statistics
N = int(sys.argv[1])
STARTED = sys.argv[2]

accepted = 0
latencies_ns = []
for line in """$RAW""".splitlines():
    if line.startswith("ACCEPTED "):
        accepted = int(line.split()[1])
    elif line.startswith("LAT "):
        latencies_ns.append(int(line.split()[1]))

latencies_ms = sorted(l / 1e6 for l in latencies_ns)
def pct(p):
    if not latencies_ms: return 0.0
    return latencies_ms[max(0, int(len(latencies_ms) * p) - 1)]

elapsed_ms = sum(latencies_ms)  # sequential — per-tx sum is wall time
tps = (accepted / (elapsed_ms / 1000.0)) if elapsed_ms else 0.0

print(json.dumps({
    "target": "algorand",
    "consensus": "BA* PureProofOfStake (dev-mode single node)",
    "version": "stable-3.24+",
    "cluster": {"nodes": 1, "location": "single-host-wsl2"},
    "workload": "transfer-500",
    "attempted": N, "accepted": accepted,
    "elapsed_ms": elapsed_ms,
    "committed_tps": tps,
    "p50_ms": pct(0.5), "p95_ms": pct(0.95), "p99_ms": pct(0.99),
    "started_at": STARTED,
    "notes": [
        "submit loop runs inside algobench-algod container (one docker exec)",
        "dev-mode commits blocks on demand; acceptance = goal returncode 0",
        "mainnet references ~1000 TPS",
    ],
}, indent=2))
PY

echo "$OUT"
cat "$OUT"
