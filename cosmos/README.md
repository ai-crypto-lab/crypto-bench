# Cosmos target

4-validator local testnet using the Cosmos SDK's reference `simd`
chain (v0.50.x). Consensus is CometBFT (ex-Tendermint) BFT.

## Requirements

- Go 1.21+
- `make`, `git`, `jq`

No docker required — `simd` is a single Go binary.

## Usage

```bash
./setup.sh            # clone cosmos-sdk v0.50, build simd, init 4-validator testnet
./bench.sh 500        # 500-tx MsgSend burst across 4 RPCs
./teardown.sh         # kills simd processes, removes testnet state
```

Output: `artifacts/cosmos/run-<timestamp>.json`.

## Why simd instead of gaiad

gaiad is the Cosmos Hub node; it's a useful production-style binary
but has a lot of features that complicate a bench (minting, IBC,
staking with slashing). `simd` is the Cosmos SDK reference chain —
identical consensus and state-machine interfaces, but with only the
bank + staking + gov modules, which is what the `transfer-500`
workload exercises.

## Version

cosmos-sdk v0.50.9 (CometBFT v0.38.x).
