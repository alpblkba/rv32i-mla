#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/tests/artifacts"

PYNQ_USER="${PYNQ_USER:-xilinx}"
PYNQ_HOST="${PYNQ_HOST:-localhost}"
PYNQ_DEST="${PYNQ_DEST:-/home/xilinx/rv32i-mla/sw/tests/artifacts}"

if [[ ! -d "$BUILD_DIR" ]]; then
  echo "build directory not found: $BUILD_DIR"
  exit 1
fi

echo "==> ensuring destination exists on PYNQ"
ssh "${PYNQ_USER}@${PYNQ_HOST}" "mkdir -p '$PYNQ_DEST'"

echo "==> pushing build artifacts to PYNQ"
rsync -av --delete "$BUILD_DIR/" "${PYNQ_USER}@${PYNQ_HOST}:$PYNQ_DEST/"

echo "push complete:"
echo "  ${PYNQ_USER}@${PYNQ_HOST}:$PYNQ_DEST"
