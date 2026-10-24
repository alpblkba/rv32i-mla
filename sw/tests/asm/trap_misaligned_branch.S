#include "isa.h"
// A taken BEQ to an address that is not 4-byte aligned traps at the branch. The contract requires halted and trap high and tohost still 0.
// encoding: 0x00000363
.section .text
.globl _start
_start:
    addi x5, x0, 0x5a
    CHECK x5, R(0), 0x5a
    beq  x0, x0, . + 6
    TOHOST_FAIL
    addi x6, x0, 0x66
    sw   x6, R(1)(x0)
    TEST_END
