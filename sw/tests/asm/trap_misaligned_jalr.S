#include "isa.h"
// JALR clears bit 0 of its target, but a target with bit 1 set still traps. The contract requires halted and trap high and tohost still 0.
// encoding: 0x002082e7
.section .text
.globl _start
_start:
    addi x5, x0, 0x5a
    CHECK x5, R(0), 0x5a
    addi x1, x0, %lo(1f)
    jalr x5, 2(x1)
1:
    TOHOST_FAIL
    addi x6, x0, 0x66
    sw   x6, R(1)(x0)
    TEST_END
