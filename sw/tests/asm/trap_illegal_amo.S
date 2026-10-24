#include "isa.h"
// LR.W belongs to the A extension, which this core does not have. The contract requires halted and trap high and tohost still 0.
// encoding: 0x100120af
.section .text
.globl _start
_start:
    addi x5, x0, 0x5a
    CHECK x5, R(0), 0x5a
    .word 0x100120af
    TOHOST_FAIL
    addi x6, x0, 0x66
    sw   x6, R(1)(x0)
    TEST_END
