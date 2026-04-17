# Workload: transfer-500

The canonical head-to-head workload used by every target in
`crypto-bench/`. Purpose: produce a throughput number that is
comparable — not identical, because trust models differ — to
OpenHash's 500-tx `node-bench-issue` burst.

## Specification

1. **Setup.** A 4-node cluster of the target system on a single host
   (WSL2 or native Linux). Fresh chain state at t=0 — the previous run's
   state must not persist. Docker `down -v`, binary `--reset`, or
   equivalent.
2. **Primitive.** A simple transfer: move 1 unit of a fungible asset
   from a sender to a receiver, signed by the sender's identity.
3. **Burst.** Submit 500 such transfers as fast as the client can issue
   them. Distribute submissions across all 4 endpoints in round-robin.
4. **Acceptance.** A transfer is counted "accepted" when the system
   returns final state (block included / transaction committed / receipt
   issued). Pending/mempool state does not count.
5. **Repetitions.** Each run is 1 repetition; the full benchmark is
   `REPS=5` runs with the cluster **fully reset** between each run.
6. **Timing.** Wall clock on the client from the first `submit` call
   to the final `accepted` confirmation. Report per-sample and
   mean ± σ over the 5 reps.

## Target-specific mapping

| Target | Primitive used |
|---|---|
| OpenHash | `TxType::Transfer` via `node-submit-issue`/`node-bench-issue` |
| Fabric | `TransferAsset` on asset-transfer-basic chaincode |
| Cosmos | `MsgSend` (bank module) |
| Ethereum | `eth_sendTransaction` with gas 21,000 |
| Solana | SystemProgram `Transfer` |
| Algorand | `PaymentTransaction` |

## Output schema

Each target's `bench.sh` must write JSON at
`artifacts/<target>/run-<N>.json` conforming to
`workloads/output-schema.json`. Minimum fields:

```json
{
  "target": "cosmos",
  "consensus": "CometBFT",
  "version": "v0.50.9",
  "cluster": { "nodes": 4, "location": "single-host-wsl2" },
  "workload": "transfer-500",
  "attempted": 500,
  "accepted": 500,
  "elapsed_ms": 3812.4,
  "committed_tps": 131.2,
  "p50_ms": 5.1,
  "p95_ms": 9.4,
  "p99_ms": 12.8,
  "started_at": "2026-04-17T14:22:00Z"
}
```

## Fair-comparison caveats (to include alongside any published table)

- **Trust model.** Permissioned (Fabric, Cosmos subset, OpenHash) vs.
  permissionless (Ethereum, Solana). Permissionless systems do more
  open-network defense work per tx — do not normalize on raw TPS.
- **Batching.** Fabric's endorsement-ordering model amortizes over
  large blocks; OpenHash commits per tx; Solana banks on PoH + leader
  rotation. Equal TPS does not mean equal per-tx work.
- **Hardware.** Results are only comparable when all targets run on
  the same host. Cross-run comparisons must say so explicitly.
- **WAN.** The single-host cluster's RTT is a Docker-bridge loopback
  floor. WAN numbers require `tc netem` or a multi-region deployment.
