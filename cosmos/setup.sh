#!/usr/bin/env bash
# Clone cosmos-sdk, build simd, and init a 4-validator localnet.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
VERSION="${COSMOS_SDK_VERSION:-v0.50.9}"
BASE="$HERE/testnet"

if ! command -v go >/dev/null; then
  echo "go not found — install Go 1.21+" >&2
  exit 2
fi

mkdir -p "$HERE/vendor"
cd "$HERE/vendor"

if [ ! -d cosmos-sdk ]; then
  git clone --depth 1 --branch "$VERSION" https://github.com/cosmos/cosmos-sdk.git
fi

cd cosmos-sdk
if [ ! -x "$HERE/vendor/simd" ]; then
  make build
  cp build/simd "$HERE/vendor/simd"
fi

SIMD="$HERE/vendor/simd"

# 4-validator localnet via built-in testnet command
rm -rf "$BASE"
"$SIMD" testnet init-files --chain-id bench-local --v 4 --output-dir "$BASE" \
  --starting-ip-address 127.0.0.1 \
  --keyring-backend test

# Each validator gets a distinct set of ports.
for i in 0 1 2 3; do
  N="node$i"
  CONF="$BASE/$N/simd/config/config.toml"
  APP="$BASE/$N/simd/config/app.toml"
  RPC_PORT=$((26657 - i*10))
  P2P_PORT=$((26656 - i*10))
  API_PORT=$((1317  + i))
  GRPC_PORT=$((9090 + i))
  # config.toml
  sed -i "s#^laddr = \"tcp://0.0.0.0:26656\"#laddr = \"tcp://127.0.0.1:$P2P_PORT\"#" "$CONF"
  sed -i "s#^laddr = \"tcp://127.0.0.1:26657\"#laddr = \"tcp://127.0.0.1:$RPC_PORT\"#" "$CONF"
  # app.toml
  sed -i "s#^address = \"tcp://0.0.0.0:1317\"#address = \"tcp://127.0.0.1:$API_PORT\"#" "$APP"
  sed -i "s#^address = \"0.0.0.0:9090\"#address = \"127.0.0.1:$GRPC_PORT\"#" "$APP"
  sed -i "s#^enable = false#enable = true#" "$APP"
done

# Wire persistent peers: each node knows about the other three.
PEERS=""
for i in 0 1 2 3; do
  NODE_ID=$("$SIMD" comet show-node-id --home "$BASE/node$i/simd")
  P2P_PORT=$((26656 - i*10))
  PEERS="$PEERS,$NODE_ID@127.0.0.1:$P2P_PORT"
done
PEERS="${PEERS#,}"
for i in 0 1 2 3; do
  sed -i "s#^persistent_peers = .*#persistent_peers = \"$PEERS\"#" \
    "$BASE/node$i/simd/config/config.toml"
done

echo "simd 4-validator localnet prepared at $BASE"
echo "start with:   ./run.sh"
