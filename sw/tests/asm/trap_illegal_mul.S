#include "isa.h"
// MUL is an OP encoding with funct7 0000001, and this core has no M or Zmmul. The contract requires halted and trap high and tohost still 0.
// encoding: 0x022081b3
.section .text
.globl _start
_start:
    addi x5, x0, 0x5a
    CHECK x5, R(0), 0x5a
    .insn r 0x33, 0, 1, x3, x1, x2
    TOHOST_FAIL
    addi x6, x0, 0x66
    sw   x6, R(1)(x0)
    TEST_END
