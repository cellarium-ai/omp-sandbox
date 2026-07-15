#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# omp-update — update OMP inside the omp-sandbox-bun named volume
#
# Usage:
#   omp-update
# ---------------------------------------------------------------------------

echo "=== OMP Updater ==="
echo ""

if ! command -v docker &>/dev/null; then
  echo "Error: Docker not found in PATH."
  exit 1
fi

if ! docker info &>/dev/null; then
  echo "Error: Docker daemon is not running."
  exit 1
fi

echo "Updating OMP in volume omp-sandbox-bun..."
echo ""

docker run --rm \
  --mount type=volume,src=omp-sandbox-bun,dst=/home/bun/.bun \
  omp-sandbox bash -c '
    cd /home/bun/.bun/install/global &&
    bun add @oh-my-pi/pi-coding-agent &&
    mkdir -p /home/bun/.bun/bin &&
    ln -sf ../install/global/node_modules/@oh-my-pi/pi-coding-agent/dist/cli.js /home/bun/.bun/bin/omp
  '

echo ""
echo "Done. Next omp-sandbox session will use the updated version."
