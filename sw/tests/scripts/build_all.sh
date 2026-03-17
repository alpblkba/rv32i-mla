#!/usr/bin/env bash
set -euo pipefail

TOOLPREFIX="${TOOLPREFIX:-riscv64-unknown-elf}"
ARCH="${ARCH:-rv32i}"
ABI="${ABI:-ilp32}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="$ROOT_DIR/tests"
ASM_DIR="$TESTS_DIR/asm"
BUILD_DIR="$TESTS_DIR/artifacts"
LINKER="$ROOT_DIR/linker.ld"

mkdir -p "$BUILD_DIR"

programs=(
  smoke
  no_branch
  branch_only
  jump_only
)

for name in "${programs[@]}"; do
  echo "==> Building $name"
  "$TOOLPREFIX-gcc" \
    -march="$ARCH" \
    -mabi="$ABI" \
    -nostdlib \
    -T "$LINKER" \
    "$ASM_DIR/$name.S" \
    -o "$BUILD_DIR/$name.elf"

  "$TOOLPREFIX-objdump" -d "$BUILD_DIR/$name.elf" > "$BUILD_DIR/$name.dump"
  "$TOOLPREFIX-objcopy" -O binary "$BUILD_DIR/$name.elf" "$BUILD_DIR/$name.bin"
done

echo
echo "build complete. artifacts are in: $BUILD_DIR"
ls -lh "$BUILD_DIR"
