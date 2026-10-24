#include "isa.h"
// MISC-MEM with funct3 010 is neither FENCE nor FENCE.I. The contract requires halted and trap high and tohost still 0.
// encoding: 0x0000200f
.section .text
.globl _start
_start:
    addi x5, x0, 0x5a
    CHECK x5, R(0), 0x5a
    .insn i 0x0f, 2, x0, x0, 0
    TOHOST_FAIL
    addi x6, x0, 0x66
    sw   x6, R(1)(x0)
    TEST_END
