#include "isa.h"
// BRANCH with funct3 010 is reserved. The contract requires halted and trap high and tohost still 0.
// encoding: 0x00002463
.section .text
.globl _start
_start:
    addi x5, x0, 0x5a
    CHECK x5, R(0), 0x5a
    .insn b 0x63, 2, x0, x0, . + 8
    TOHOST_FAIL
    addi x6, x0, 0x66
    sw   x6, R(1)(x0)
    TEST_END
