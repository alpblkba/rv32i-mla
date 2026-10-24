#include "isa.h"
// The all-zero word is illegal. The contract requires halted and trap high and tohost still 0.
// encoding: 0x00000000
.section .text
.globl _start
_start:
    addi x5, x0, 0x5a
    CHECK x5, R(0), 0x5a
    .word 0x00000000
    TOHOST_FAIL
    addi x6, x0, 0x66
    sw   x6, R(1)(x0)
    TEST_END
