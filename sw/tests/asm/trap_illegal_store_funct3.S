#include "isa.h"
// STORE with funct3 011 is SD from RV64. The contract requires halted and trap high and tohost still 0.
// encoding: 0x40103023
.section .text
.globl _start
_start:
    addi x5, x0, 0x5a
    CHECK x5, R(0), 0x5a
    .insn s 0x23, 3, x1, 0x400(x0)
    TOHOST_FAIL
    addi x6, x0, 0x66
    sw   x6, R(1)(x0)
    TEST_END
