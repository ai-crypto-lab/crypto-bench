#!/usr/bin/env bash
# Liveness check: for each target, try a lightweight RPC call and
# report whether it's reachable.
set -uo pipefail

check_cosmos()   { curl -sS -m 2 http://127.0.0.1:26657/status >/dev/null && echo "UP" || echo "DOWN"; }
check_ethereum() { curl -sS -m 2 -H 'content-type: application/json' \
                     -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
                     http://127.0.0.1:8545 >/dev/null && echo "UP" || echo "DOWN"; }
check_solana()   { curl -sS -m 2 -H 'content-type: application/json' \
                     -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' \
                     http://127.0.0.1:8899 >/dev/null && echo "UP" || echo "DOWN"; }
check_algorand() { curl -sS -m 2 -H 'X-Algo-API-Token: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
                     http://127.0.0.1:4001/v2/status >/dev/null && echo "UP" || echo "DOWN"; }
check_fabric()   { docker ps --filter 'name=peer0.org1' --format '{{.Status}}' | grep -q healthy && echo "UP" || echo "DOWN"; }

printf "%-10s %-5s\n" "target" "status"
for t in cosmos ethereum solana algorand fabric; do
  status=$("check_$t")
  printf "%-10s %-5s\n" "$t" "$status"
done
