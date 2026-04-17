# crypto-bench

Controlled-workload benchmark environments for the five distributed
ledgers that OpenHash Core compares against in its v0.1.1 preprint
(`openhash-core/docs/paper/openhash-preprint.md` §5.6 / Appendix A):

| Target | Consensus | Typical reference TPS | Sibling directory |
|---|---|---|---|
| Hyperledger Fabric 2.5 | Raft ordering + endorsement | ~3,500 (published, 500-tx blocks) | `fabric/` |
| Cosmos SDK + CometBFT | Tendermint BFT | ~1,000–3,500 (4–100 validators) | `cosmos/` |
| Ethereum (geth, Clique PoA) | PoA, 4 signers | ~15–25 (mainnet); ~1–2 k (PoA dev) | `ethereum/` |
| Solana test-validator | PoH + Tower BFT | 3 k–4.5 k (mainnet real-time) | `solana/` |
| Algorand sandbox | BA★ Pure PoS | ~1 k (mainnet) | `algorand/` |

## Why this sibling directory and not a sub-tree of `openhash-core`?

1. Each target lives under its own upstream release cadence and disk
   footprint. Keeping them outside the OpenHash workspace avoids
   accidentally dragging docker images, genesis state, and
   chain-specific toolchains into OpenHash's reproducibility artifacts.
2. The benchmark runner produces *comparison artifacts* — JSON + CSV
   with the same schema as OpenHash's own measurement output — which
   then get committed into `openhash-core/artifacts/experiments/` as
   references for the preprint. Only the artifacts cross the boundary;
   the infrastructure stays here.
3. If any target has a blocker specific to WSL2 (documented for Fabric
   in `openhash-core/docs/paper/fabric-attempt-note.md`) the workaround
   is isolated to that target's subdirectory.

## Shared workload

The canonical head-to-head workload is defined in
`workloads/transfer-500.md`. Every target's `bench.sh` must execute it
and emit a JSON metrics file with the fields listed in
`workloads/output-schema.json`. The OpenHash reference implementation
of this workload lives at
`openhash-core/scripts/p0-distributed-reps.sh`.

## Running all benches

```bash
# From /home/kjs/projects/crypto-bench/
./tools/setup-all.sh          # installs what can be auto-installed
./comparison/run-all.sh       # runs the 500-tx workload on every target
./comparison/summarize.py     # emits comparison.csv + comparison.md
```

Individual targets can be run standalone — each `<target>/` subdir is
self-contained with its own `setup.sh`, `bench.sh`, `teardown.sh`, and
`README.md`.

## Status

| Target | Setup script | Bench script | Works on WSL2? | Notes |
|---|---|---|---|---|
| fabric | drafted | drafted | blocked | docker-in-docker chaincode build; workaround in `fabric/README.md` |
| cosmos | drafted | drafted | yes | simd from Cosmos SDK v0.50, 4-validator local testnet |
| ethereum | drafted | drafted | yes | geth 1.13+ Clique PoA, 4 signers |
| solana | drafted | drafted | yes | solana-test-validator single-node localnet |
| algorand | drafted | drafted | likely | algorand/stable docker image |

"drafted" means the scripts are in place but have not been
end-to-end executed in this environment. Run `./tools/setup-all.sh`
to materialize the toolchains; re-run this matrix from
`./comparison/status.sh` to see current liveness.

## License / attribution

Each target's code is governed by its own upstream license. Wrapper
scripts in this directory are MIT-licensed; see `LICENSE`.
