# Ethereum target

`go-ethereum` (geth) 1.13+ in Clique PoA mode, 4 signers on a single
host. This is **not** mainnet geth — Clique is retired there but is
still supported as a dev-friendly PoA consensus with deterministic
block times. It is the closest same-host apples-to-apples against a
permissioned OpenHash cluster.

## Requirements

- Docker Engine.
- No other host-level tooling; everything runs inside the
  `ethereum/client-go:v1.13.15` image.

## Usage

```bash
./setup.sh            # render genesis, init data dirs, start 4-node docker compose
./bench.sh 500        # 500-tx eth_sendTransaction burst
./teardown.sh
```

Output: `artifacts/ethereum/run-<timestamp>.json`.

## Why Clique PoA, not PoS / mainnet

A mainnet PoS geth node needs a consensus-layer client (prysm, lighthouse)
plus a beacon checkpoint sync. Setting that up on a single host to run a
500-tx burst is not worth it — the 15–25 mainnet TPS figure is reported
by Etherscan and cited directly in OpenHash's baseline comparison. The
point of running geth here is to quantify the same-host PoA ceiling, so
the client-side gRPC/HTTP overhead is comparable to OpenHash's own
gateway, not to re-derive mainnet's number.

## Version

go-ethereum v1.13.15 (last Clique-friendly release before PoS-only
flips became default).
