#!/usr/bin/env bash
# Render genesis with 4 signer addresses, init each node's data dir,
# and bring up the 4-node Clique PoA cluster.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMAGE="ethereum/client-go:v1.13.15"

if ! command -v docker >/dev/null; then
  echo "docker not found" >&2; exit 2
fi

mkdir -p "$HERE/data/"{a,b,c,d}
for d in a b c d; do
  mkdir -p "$HERE/data/$d/keystore"
  echo "bench" > "$HERE/data/$d/password.txt"
  if [ -z "$(ls "$HERE/data/$d/keystore" 2>/dev/null)" ]; then
    docker run --rm -v "$HERE/data/$d":/data -w /data "$IMAGE" \
      account new --password /data/password.txt
  fi
done

# Read each node's signer address
SIGNERS=""
for d in a b c d; do
  KS=$(ls "$HERE/data/$d/keystore" | head -1)
  ADDR=$(python3 -c "import json; print(json.load(open('$HERE/data/$d/keystore/$KS'))['address'])")
  SIGNERS="${SIGNERS}${ADDR}"
done

# Clique extradata: 32-byte vanity + concat(signers, 20B each) + 65-byte zero seal
EXTRA="0x$(printf '0%.0s' $(seq 1 64))${SIGNERS}$(printf '0%.0s' $(seq 1 130))"

# Patch genesis with this extradata and each signer's allocation
python3 - <<PY
import json
g = json.load(open("$HERE/genesis.json"))
g["extradata"] = "$EXTRA"
for d in ["a", "b", "c", "d"]:
    import os
    ks = os.listdir("$HERE/data/" + d + "/keystore")[0]
    addr = json.load(open("$HERE/data/" + d + "/keystore/" + ks))["address"]
    g["alloc"]["0x" + addr] = {"balance": "0x200000000000000000000"}
json.dump(g, open("$HERE/genesis.rendered.json", "w"), indent=2)
print("rendered genesis with", len("$SIGNERS") // 40, "signers")
PY

# Init each datadir
for d in a b c d; do
  docker run --rm -v "$HERE":/here -v "$HERE/data/$d":/data "$IMAGE" \
    init --datadir /data /here/genesis.rendered.json
done

cd "$HERE"
docker compose up -d
sleep 4
docker compose ps
echo "geth 4-signer Clique cluster up on :8545..:8548"
