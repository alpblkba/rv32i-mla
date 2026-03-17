#!/usr/bin/env bash
set -euo pipefail

# Host-side script.
# Pushes the local sw/ directory to the PYNQ board and builds the native C app there.

BOARD_USER="${BOARD_USER:-xilinx}"
BOARD_HOST="${BOARD_HOST:-localhost}"
BOARD_PORT="${BOARD_PORT:-22}"

# Local project paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SW_DIR="${SW_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

# Remote project path on the board
REMOTE_BASE="${REMOTE_BASE:-/home/${BOARD_USER}/rv32i-mla}"
REMOTE_SW_DIR="${REMOTE_SW_DIR:-${REMOTE_BASE}/sw}"

echo "Local sw/      : ${SW_DIR}"
echo "Remote sw/     : ${BOARD_USER}@${BOARD_HOST}:${REMOTE_SW_DIR}"
echo "SSH port       : ${BOARD_PORT}"
echo

# Ensure remote base exists
ssh -p "${BOARD_PORT}" "${BOARD_USER}@${BOARD_HOST}" "mkdir -p '${REMOTE_BASE}'"

# Push sw/ to board
# Excludes native build outputs so board rebuild is always clean.
# Keeps tests/artifacts unless you rename or exclude them separately.
rsync -avz --delete \
  -e "ssh -p ${BOARD_PORT}" \
  --exclude 'build/' \
  --exclude '.DS_Store' \
  "${SW_DIR}/" \
  "${BOARD_USER}@${BOARD_HOST}:${REMOTE_SW_DIR}/"

echo
echo "Source sync complete. Starting remote build..."
echo

# Build on board
ssh -t -p "${BOARD_PORT}" "${BOARD_USER}@${BOARD_HOST}" "
  set -e
  cd '${REMOTE_SW_DIR}'
  mkdir -p build
  make clean || true
  make
  echo
  echo 'Build completed.'
  ls -l build/
"
