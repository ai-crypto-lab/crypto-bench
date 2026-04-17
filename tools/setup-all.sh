#!/usr/bin/env bash
# Try to stand up every target in sequence. Non-blocking — each
# target's setup.sh either succeeds or logs its blocker and moves on.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

for target in cosmos ethereum solana algorand fabric; do
  SETUP="$REPO/$target/setup.sh"
  if [ ! -x "$SETUP" ]; then
    echo "[$target] no setup.sh — skipping"
    continue
  fi
  echo "=================================================="
  echo "  setting up $target"
  echo "=================================================="
  if ! "$SETUP"; then
    echo "[$target] setup FAILED — continue with the rest"
  fi
done

"$REPO/comparison/status.sh"
