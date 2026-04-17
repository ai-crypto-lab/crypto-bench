#!/usr/bin/env bash
# Run a 500-tx TransferAsset burst against the Fabric test-network.
#
# Fabric's canonical client is the Node Gateway SDK; the test-network
# ships an example invoker. We wrap it to time N TransferAsset calls and
# emit a JSON in crypto-bench's output schema.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
N="${1:-500}"
OUT_DIR="${HERE}/../artifacts/fabric"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/run-$(date -u +%Y%m%dT%H%M%SZ).json"

SAMPLE_APP="$HERE/vendor/fabric-samples/asset-transfer-basic/application-gateway-typescript"
if [ ! -d "$SAMPLE_APP" ]; then
  echo "fabric-samples not installed; run ./setup.sh first" >&2
  exit 2
fi

cd "$SAMPLE_APP"
[ -d node_modules ] || npm install >/dev/null

# The sample app creates a fresh asset then transfers it once per run.
# For the burst we override its main loop with a 500-iteration variant.
cat > run-burst.ts <<'TS'
import { ConnectOptions, Gateway, connect } from '@hyperledger/fabric-gateway';
import { resolve } from 'node:path';

const N = parseInt(process.env.N ?? '500', 10);

// Minimal Gateway connect scaffolding — the Fabric sample has the full
// certificate + grpc client setup; we import the helpers from it.
const { newGrpcConnection, newIdentity, newSigner } = await import('./src/connect.ts');

async function main() {
  const client = await newGrpcConnection();
  const gateway: Gateway = connect({
    client,
    identity: await newIdentity(),
    signer: await newSigner(),
  } as ConnectOptions);

  try {
    const network  = gateway.getNetwork('mychannel');
    const contract = network.getContract('basic');

    await contract.submitTransaction('InitLedger');

    const started = Date.now();
    const latencies: number[] = [];
    for (let i = 0; i < N; i++) {
      const t0 = Date.now();
      await contract.submitTransaction(
        'TransferAsset',
        'asset1',
        `alice-${i}`,
      );
      latencies.push(Date.now() - t0);
    }
    const elapsed = Date.now() - started;
    latencies.sort((a, b) => a - b);
    const pct = (p: number) => latencies[Math.floor(latencies.length * p) - 1];
    const out = {
      target: 'fabric',
      consensus: 'Raft-ordering+endorsement',
      version: process.env.FABRIC_VERSION ?? '2.5.9',
      cluster: { nodes: 4, location: 'single-host-wsl2' },
      workload: 'transfer-500',
      attempted: N,
      accepted: N,
      elapsed_ms: elapsed,
      committed_tps: (N / elapsed) * 1000,
      p50_ms: pct(0.5),
      p95_ms: pct(0.95),
      p99_ms: pct(0.99),
      started_at: new Date(started).toISOString(),
    };
    process.stdout.write(JSON.stringify(out, null, 2));
  } finally {
    gateway.close();
    client.close();
  }
}

await main();
TS

npx tsx run-burst.ts > "$OUT"
echo "$OUT"
cat "$OUT"
