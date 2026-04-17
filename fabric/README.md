# Fabric target

Hyperledger Fabric 2.5 test-network, 2-org / 2-peer / 1-orderer
configuration, Raft ordering. Runs the `asset-transfer-basic`
chaincode in Go.

## Known WSL2 blocker

`openhash-core/docs/paper/fabric-attempt-note.md` records a previous
attempt that hit a docker-in-docker chaincode build failure on WSL2
with the JavaScript chaincode. **Use the Go variant** here — it
avoids the `fabric-nodeenv` image path entirely and stays inside
the `fabric-ccenv` image which has a reliable docker socket on WSL2
when BuildKit is off.

If the build still fails, set:

```bash
export DOCKER_BUILDKIT=0
```

before running `./setup.sh`. This was the smoking gun in
2026-04-16's attempt.

## Requirements

- Docker Engine or Docker Desktop with Linux-containers mode.
- Go 1.21 or newer on the host (needed for chaincode module
  introspection). Install with:
  ```bash
  curl -sL https://go.dev/dl/go1.21.13.linux-amd64.tar.gz | \
    sudo tar -C /usr/local -xz
  export PATH=/usr/local/go/bin:$PATH
  ```
- Approximately 6 GB of disk for Fabric images.

## Usage

```bash
./setup.sh            # install Fabric 2.5.9 binaries + images, bring up test-network
./bench.sh 500        # run 500-tx transfer burst
./teardown.sh         # ./network.sh down
```

Output: `artifacts/fabric/run-<timestamp>.json`.

## Version

Fabric v2.5.9 + CA 1.5.12 — same as the previous attempt, for
traceability with the note referenced above.
