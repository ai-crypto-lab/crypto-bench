#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
docker compose up -d
sleep 3
docker exec algobench-algod /node/bin/goal node status -d /algod/data \
  | head -20 || true
echo "algod dev-mode up on :4001 (TOKEN='aaaaa...')"
