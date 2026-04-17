# Algorand target

Algorand private network via the official `algorand/algod` docker
image in dev-mode. Dev-mode is a single-node network that produces
blocks on-demand — not apples-to-apples with Algorand mainnet's ~1 k
mainnet TPS, but the same role as Solana's test-validator for this
bench harness.

## Requirements

- Docker Engine.

## Usage

```bash
./setup.sh            # pull algorand/algod, start dev-mode network
./bench.sh 500        # 500 PaymentTransactions
./teardown.sh
```

Output: `artifacts/algorand/run-<timestamp>.json`.

## Why dev-mode and not a 4-validator private network

Running a real 4-validator Algorand private net needs an offline
genesis-ceremony + kmd wallet bootstrap + explicit participation
key registration. Dev-mode short-circuits that by letting the
single node self-stake and cut blocks on demand. This is the same
trade-off Solana forces (single-validator localnet), so reporting
them both with `cluster.nodes=1` is consistent.

## Version

algorand/algod:stable (3.24+).
