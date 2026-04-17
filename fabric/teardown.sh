#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
if [ -d "$HERE/vendor/fabric-samples/test-network" ]; then
  (cd "$HERE/vendor/fabric-samples/test-network" && ./network.sh down)
fi
