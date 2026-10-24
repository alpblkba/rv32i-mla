#include "isa.h"
// SLL with funct7 0100000 is not one of the 37 instructions. The contract requires halted and trap high and tohost still 0.
// encoding: 0x402091b3
.section .text
.globl _start
_start:
    addi x5, x0, 0x5a
    CHECK x5, R(0), 0x5a
    .insn r 0x33, 1, 0x20, x3, x1, x2
    TOHOST_FAIL
    addi x6, x0, 0x66
    sw   x6, R(1)(x0)
    TEST_END
