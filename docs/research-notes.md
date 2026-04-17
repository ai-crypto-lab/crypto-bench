# Research Notes — why these five targets and how they're set up

OpenHash positions itself in §1 of the preprint against the
permissioned DLT lineage (Fabric, Corda), the BFT variant lineage
(PBFT, HotStuff, LPBFT), and — for calibration — a handful of
permissionless systems that dominate real-world throughput
conversations. The five targets in this directory are the reference
set: any claim about OpenHash's throughput that a reviewer would ask
about gets answered by running the `transfer-500` workload here.

The selection criteria were:

1. **Peer-reviewed origin.** Every target has a peer-reviewed paper
   or widely-cited whitepaper the community agrees on (listed inline
   below).
2. **Open-source + reproducible.** We only include systems whose
   source is public and whose localnet/dev-mode can be stood up from
   a single `setup.sh` on the same workstation as OpenHash.
3. **Distinct design point.** Each target exercises a different
   consensus / execution design, so the comparison is not five runs
   of the same idea.

## Per-target notes

### Hyperledger Fabric

**Design point.** Permissioned, execute-order-validate — transactions
are endorsed by a subset of peers, then ordered by a dedicated ordering
service (Raft), then each peer re-executes them in order.
**Published ref.** Androulaki et al., *Hyperledger Fabric: A Distributed
Operating System for Permissioned Blockchains*, EuroSys 2018.
**Why this bench.** Closest permissioned sibling to OpenHash. Both run
4-node local clusters, both have out-of-path ordering, both require
explicit signer set management. Direct comparison is meaningful on the
transfer-500 workload.
**Known blocker on WSL2.** Previously-attempted JavaScript chaincode
fails due to docker-in-docker BuildKit issues
(`openhash-core/docs/paper/fabric-attempt-note.md`). We default to Go
chaincode + `DOCKER_BUILDKIT=0` here, which the previous note
identified as the unblocker.

### Cosmos SDK + CometBFT

**Design point.** Permissioned-by-default (but open validator set),
Tendermint BFT on the commit path.
**Published ref.** Buchman, Kwon, Milosevic, *The latest gossip on BFT
consensus*, arXiv:1807.04938.
**Why this bench.** BFT-on-commit-path is exactly the design choice
OpenHash rejects in favor of recovery-only LPBFT. Running both on the
same workload quantifies what recovery-only buys in steady-state
throughput.
**Why simd, not gaiad.** simd is the reference chain that ships with
cosmos-sdk; gaiad is the Cosmos Hub production node. The consensus +
state-machine interfaces are identical; simd excludes IBC, slashing,
and governance modules, which keeps the `transfer-500` workload from
being noisy with unrelated activity.

### Ethereum (geth + Clique PoA)

**Design point.** Permissionless (though Clique is a degenerate PoA
for dev use). Account-based state, EVM execution, JSON-RPC.
**Published ref.** Wood, *Ethereum Yellow Paper*, 2014–2025 revisions.
**Why this bench.** The volumetric reference — any distributed-ledger
comparison eventually gets asked "how does it stack against Ethereum."
Running Clique PoA locally is the closest apples-to-apples because it
removes the PoS consensus layer's overhead. The 15–25 TPS mainnet
figure comes from Etherscan; Clique dev typically measures 1–2 k TPS
on the same hardware.
**Why geth 1.13.15.** Last release where Clique is a first-class dev
option before PoS-only defaults took over.

### Solana

**Design point.** Permissionless, PoH + Tower BFT, single-leader per
slot, GPU-accelerated signature verification on real mainnet.
**Published ref.** Yakovenko, *Solana: A new architecture for a high
performance blockchain* (v0.8.13), 2017 whitepaper.
**Why this bench.** Counter-example to OpenHash's low-overhead commit
path — Solana achieves its numbers via aggressive optimization on a
leader-centric design. Running `solana-test-validator` lets us observe
the single-validator ceiling on the same hardware.
**Why single-validator.** Solana doesn't have a meaningful 4-validator
localnet without a complex stake-weighted bootstrap. The upstream
stance (https://docs.solanalabs.com/cli/examples/test-validator) is
that test-validator is the right way to benchmark locally.

### Algorand

**Design point.** Pure PoS, BA★ consensus with cryptographic sortition.
**Published ref.** Gilad, Hemo, Micali, Vlachos, Zeldovich, *Algorand:
Scaling Byzantine Agreements for Cryptocurrencies*, SOSP 2017.
**Why this bench.** Design point distinct from all of the above —
sortition-selected block proposer, pre-committee verification. Mainnet
figure (~1 k TPS in 2024, 2025 upgrade targeting ~3 k TPS).
**Why dev-mode.** Same reasoning as Solana — a real 4-validator
Algorand testnet needs an offline genesis ceremony. Dev-mode keeps
the friction low while still running the actual state machine.

## What this directory deliberately does not include

- **Corda.** Closest in spirit to OpenHash (notary-based ordering,
  permissioned) but setup on a single host requires the corda-node JVM
  + a notary process + compiled CorDapps. The time-to-bench is high
  and the published figures (500–1500 TPS) overlap with Fabric's
  range enough that the calibration value is limited.
- **Polkadot / Substrate.** Interesting design but the smallest
  test-network is a 2-validator Substrate node which doesn't stress
  the consensus path. Skipped.
- **Avalanche.** C-Chain localnet exists but is essentially a re-skin
  of Ethereum EVM — adding it would double geth without a new signal.
- **Private "proof-of-authority" nets for other EVM derivatives**
  (Polygon, Arbitrum, Optimism localnets). Same EVM+PoA dynamics as
  our geth/Clique target; redundant.
- **Diem / Libra / Aptos / Sui.** Aptos and Sui are interesting
  (Move-based, parallel-execution-aware). If we ever add a second EVM-
  adjacent target, Aptos localnet is the first choice.

## What gets committed back to OpenHash

`artifacts/comparison.{csv,md,json}` produced by
`comparison/summarize.py` is the expected return artifact. It goes
into `openhash-core/artifacts/experiments/same-host-head-to-head/`
and feeds Table 3 of §5.6. Raw `run-*.json` stay here — they are
verbose and target-specific.
