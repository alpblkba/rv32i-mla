#include "isa.h"
// LHU from an odd address is a misaligned halfword. The contract requires halted and trap high and tohost still 0.
// encoding: 0x40305183
.section .text
.globl _start
_start:
    addi x5, x0, 0x5a
    CHECK x5, R(0), 0x5a
    lhu  x3, R(0) + 3(x0)
    TOHOST_FAIL
    addi x6, x0, 0x66
    sw   x6, R(1)(x0)
    TEST_END
