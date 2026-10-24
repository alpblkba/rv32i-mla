# Vendored riscv-tests

These files come from https://github.com/riscv-software-src/riscv-tests at commit `3df703cd52d5f0d8224e3c50bf03c6cb70efff98` (2026-10-19, "Initialize the full CBO.ZERO test block (#673)"), under the BSD licence in `LICENSE`. They are byte for byte the upstream files.

`isa/rv32ui/` holds 40 of the 42 rv32ui programs, `isa/rv64ui/` holds the 40 files they include, and `isa/macros/scalar/test_macros.h` is the scalar macro header. `fence_i` and `ma_data` are left out as the contract requires, since this core has no Zifencei and traps on misaligned data.

`env/riscv_test.h` and `link.ld` are local and replace the upstream `env` submodule, which is not vendored. The header uses no CSR and writes the result to `tohost` at `0x1ffc`: 1 on pass, `(TESTNUM << 1) | 1` on fail, both followed by `ecall` and `jal x0, 0`. The linker script places code and data from `0x0` and `tohost` alone at `0x1ffc`.

To refresh the files, check out a newer commit, copy the same paths, and record the new commit here.
