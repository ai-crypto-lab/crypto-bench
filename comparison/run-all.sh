#!/usr/bin/env bash
# Run the transfer-500 workload across every target that is currently
# healthy, collecting per-target run JSONs under artifacts/<target>/.
#
# Each target's health check is its own responsibility; this wrapper
# just honors whatever the target's own bench.sh returns.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
REPS="${REPS:-5}"
N="${N:-500}"

for target in cosmos ethereum solana algorand fabric; do
  BENCH="$REPO/$target/bench.sh"
  if [ ! -x "$BENCH" ]; then
    echo "[$target] no bench.sh or not executable — skipping"
    continue
  fi
  echo "=== $target — $REPS reps × $N tx ==="
  for rep in $(seq 1 "$REPS"); do
    echo "--- rep $rep/$REPS ---"
    if ! "$BENCH" "$N"; then
      echo "[$target] rep $rep FAILED"
    fi
  done
done

echo
"$HERE/summarize.py"
