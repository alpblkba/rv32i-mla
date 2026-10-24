#include "isa.h"
// The OP-IMM-32 opcode of ADDIW exists only on RV64. The contract requires halted and trap high and tohost still 0.
// encoding: 0x0010809b
.section .text
.globl _start
_start:
    addi x5, x0, 0x5a
    CHECK x5, R(0), 0x5a
    .insn i 0x1b, 0, x1, x1, 1
    TOHOST_FAIL
    addi x6, x0, 0x66
    sw   x6, R(1)(x0)
    TEST_END
