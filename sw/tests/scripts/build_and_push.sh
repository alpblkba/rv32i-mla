#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/tests/scripts/build_all.sh"
"$ROOT_DIR/tests/scripts/push_build.sh"
