#!/usr/bin/env bash
# Clone cosmos-sdk, build simd, and init a 4-validator localnet.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
VERSION="${COSMOS_SDK_VERSION:-v0.50.9}"
BASE="$HERE/testnet"

if ! command -v go >/dev/null; then
  echo "go not found on host — will build simd inside golang:1.21 container"
fi

mkdir -p "$HERE/vendor"

if [ ! -x "$HERE/vendor/simd" ]; then
  # Build simd in a golang container when no host Go toolchain is
  # available — keeps the bench environment hermetic.
  (cd "$HERE/vendor" && docker run --rm -v "$PWD":/out -w /out golang:1.21 bash -c \
    "apt-get update -q && apt-get install -qy git build-essential && \
     git clone --depth 1 --branch ${COSMOS_SDK_VERSION:-v0.50.9} https://github.com/cosmos/cosmos-sdk.git && \
     cd cosmos-sdk && make build && cp build/simd /out/simd && \
     chown $(id -u):$(id -g) /out/simd 2>/dev/null || true")
fi

SIMD="$HERE/vendor/simd"

# Validator count: default 1 (single-host WSL2 addr_book mesh is
# flaky). Override with V=4 for a proper multi-validator test.
V="${V:-1}"
rm -rf "$BASE"
"$SIMD" testnet init-files --chain-id bench-local --v "$V" --output-dir "$BASE" \
  --starting-ip-address 127.0.0.1 \
  --keyring-backend test

# Each validator gets a distinct set of ports. We rewrite the four
# toml listen addresses regardless of whether they default to 0.0.0.0
# or 127.0.0.1 — `simd testnet init-files` sometimes produces each.
for i in $(seq 0 $((V - 1))); do
  N="node$i"
  CONF="$BASE/$N/simd/config/config.toml"
  APP="$BASE/$N/simd/config/app.toml"
  RPC_PORT=$((26657 - i*10))
  P2P_PORT=$((26656 - i*10))
  API_PORT=$((1317  + i))
  GRPC_PORT=$((9090 + i))
  # config.toml
  sed -i -E "s#^(laddr = \"tcp://[0-9.]+:)26656(\")#\\1$P2P_PORT\\2#" "$CONF"
  sed -i -E "s#^(laddr = \"tcp://[0-9.]+:)26657(\")#\\1$RPC_PORT\\2#" "$CONF"
  # app.toml
  sed -i -E "s#^(address = \"tcp://[0-9.]+:)1317(\")#\\1$API_PORT\\2#" "$APP"
  sed -i -E "s#^(address = \"[0-9.]+:)9090(\")#\\1$GRPC_PORT\\2#" "$APP"
  sed -i "s#^enable = false#enable = true#" "$APP"
done

# Wire persistent peers: each node knows about the others.
if [ "$V" -gt 1 ]; then
  PEERS=""
  for i in $(seq 0 $((V - 1))); do
    NODE_ID=$("$SIMD" comet show-node-id --home "$BASE/node$i/simd")
    P2P_PORT=$((26656 - i*10))
    PEERS="$PEERS,$NODE_ID@127.0.0.1:$P2P_PORT"
  done
  PEERS="${PEERS#,}"
  for i in $(seq 0 $((V - 1))); do
    sed -i "s#^persistent_peers = .*#persistent_peers = \"$PEERS\"#" \
      "$BASE/node$i/simd/config/config.toml"
  done
fi

echo "simd 4-validator localnet prepared at $BASE"
echo "start with:   ./run.sh"
