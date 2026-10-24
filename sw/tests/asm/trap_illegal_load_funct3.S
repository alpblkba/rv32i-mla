#include "isa.h"
// LOAD with funct3 011 is LD from RV64. The contract requires halted and trap high and tohost still 0.
// encoding: 0x40003183
.section .text
.globl _start
_start:
    addi x5, x0, 0x5a
    CHECK x5, R(0), 0x5a
    .insn i 0x03, 3, x3, x0, 0x400
    TOHOST_FAIL
    addi x6, x0, 0x66
    sw   x6, R(1)(x0)
    TEST_END
