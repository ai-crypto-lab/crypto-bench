#!/usr/bin/env bash
# Install Fabric 2.5.9 and bring up the canonical test-network with
# asset-transfer-basic (Go) deployed.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
FABRIC_VERSION="${FABRIC_VERSION:-2.5.9}"
CA_VERSION="${CA_VERSION:-1.5.12}"

export DOCKER_BUILDKIT=0   # avoid the WSL2 BuildKit chaincode-build blocker

if ! command -v docker >/dev/null 2>&1; then
  echo "docker not found; install Docker Desktop or docker.io first" >&2
  exit 2
fi
if ! command -v go >/dev/null 2>&1; then
  echo "go not found; chaincode-go packaging requires go 1.21+" >&2
  exit 2
fi

mkdir -p "$HERE/vendor"
cd "$HERE/vendor"

if [ ! -d fabric-samples ]; then
  curl -sSL https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh \
    -o install-fabric.sh
  chmod +x install-fabric.sh
  ./install-fabric.sh --fabric-version "$FABRIC_VERSION" \
                      --ca-version "$CA_VERSION" \
                      docker samples binary
fi

cd fabric-samples/test-network

./network.sh down 2>/dev/null || true
./network.sh up createChannel -c mychannel -ca
./network.sh deployCC -ccn basic \
  -ccp ../asset-transfer-basic/chaincode-go \
  -ccl go

echo
echo "fabric test-network up. peers:"
docker ps --filter 'name=peer0' --format '{{.Names}} {{.Ports}}'
