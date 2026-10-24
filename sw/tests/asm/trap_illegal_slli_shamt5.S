#include "isa.h"
// SLLI with imm[5] set is reserved on RV32. The contract requires halted and trap high and tohost still 0.
// encoding: 0x02009193
.section .text
.globl _start
_start:
    addi x5, x0, 0x5a
    CHECK x5, R(0), 0x5a
    .insn i 0x13, 1, x3, x1, 0x020
    TOHOST_FAIL
    addi x6, x0, 0x66
    sw   x6, R(1)(x0)
    TEST_END
