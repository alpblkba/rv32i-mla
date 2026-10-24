#include "isa.h"
// SH to an odd address is a misaligned halfword, and memory must stay unchanged. The contract requires halted and trap high and tohost still 0.
// encoding: 0x405014a3
.section .text
.globl _start
_start:
    addi x5, x0, 0x5a
    CHECK x5, R(0), 0x5a
    sh   x5, R(2) + 1(x0)
    TOHOST_FAIL
    addi x6, x0, 0x66
    sw   x6, R(1)(x0)
    TEST_END
