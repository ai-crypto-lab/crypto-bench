#!/usr/bin/env bash
# 500-tx SystemProgram::Transfer burst against solana-test-validator.
#
# Uses `solana transfer` CLI; for higher-fidelity latency measurement a
# web3.js client is preferable, but the CLI keeps dependencies minimal
# and stays in the same spirit as cosmos/bench.sh.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
N="${1:-500}"
OUT_DIR="$HERE/../artifacts/solana"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/run-$(date -u +%Y%m%dT%H%M%SZ).json"

solana config set --url http://127.0.0.1:8899 >/dev/null
FROM=$(solana address)
TO=$(solana-keygen pubkey "$HERE/recipient.json" 2>/dev/null || \
     solana-keygen new --no-bip39-passphrase --silent -o "$HERE/recipient.json" | \
     grep -oP 'pubkey: \K[1-9A-HJ-NP-Za-km-z]+')

solana airdrop 100 "$FROM" --url http://127.0.0.1:8899 >/dev/null

python3 - "$N" "$FROM" "$TO" > "$OUT" <<'PY'
import json, subprocess, sys, time

N = int(sys.argv[1])
FROM = sys.argv[2]
TO = sys.argv[3]

latencies = []
accepted = 0
start = time.time()
for i in range(N):
    t0 = time.time()
    r = subprocess.run(
        ["solana", "transfer", TO, "0.000001",
         "--from", "--url", "http://127.0.0.1:8899",
         "--no-wait", "--allow-unfunded-recipient"],
        capture_output=True, text=True,
    )
    latencies.append((time.time() - t0) * 1000.0)
    if r.returncode == 0:
        accepted += 1

elapsed = (time.time() - start) * 1000.0
latencies.sort()
pct = lambda p: latencies[max(0, int(len(latencies)*p) - 1)] if latencies else 0
print(json.dumps({
    "target": "solana",
    "consensus": "PoH+TowerBFT (single validator)",
    "version": "v1.18.26",
    "cluster": {"nodes": 1, "location": "single-host-wsl2"},
    "workload": "transfer-500",
    "attempted": N, "accepted": accepted,
    "elapsed_ms": elapsed,
    "committed_tps": (accepted / elapsed) * 1000 if elapsed else 0,
    "p50_ms": pct(0.5), "p95_ms": pct(0.95), "p99_ms": pct(0.99),
    "started_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(start)),
    "notes": [
        "solana-test-validator is a single-leader localnet, not a multi-validator deployment",
        "transfer via CLI --no-wait; acceptance = CLI returned 0 (submitted), not necessarily confirmed",
    ],
}, indent=2))
PY

echo "$OUT"
cat "$OUT"
