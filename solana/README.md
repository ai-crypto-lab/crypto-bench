# Solana target

Single-node `solana-test-validator` localnet. Solana does not run a
meaningful 4-validator localnet — the published mainnet throughput
figure is a single-leader-per-slot measurement, and `test-validator`
is the upstream-sanctioned way to reproduce it locally.

## Requirements

- `solana-cli` v1.18+ (bundled validator).

## Usage

```bash
./setup.sh            # install solana-cli if missing; start test-validator
./bench.sh 500        # 500-tx SystemProgram::Transfer burst
./teardown.sh
```

Output: `artifacts/solana/run-<timestamp>.json`.

## Why single-node and still called "cluster":4

In the output schema `cluster.nodes` is the number of cooperating
validators the workload observes. Solana's test-validator is one
validator emitting one stream of blocks, and that is an honest number
to report. It is **not** comparable to a 4-peer permissioned system on
trust assumptions — which is exactly the point of the "fair-comparison
caveats" section in the paper.

## Version

solana-cli 1.18.x (last pre-Firedancer stable as of 2026-04).
