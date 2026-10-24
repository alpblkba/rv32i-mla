#include "isa.h"
// The custom-0 opcode stays unassigned. The contract requires halted and trap high and tohost still 0.
// encoding: 0x0031008b
.section .text
.globl _start
_start:
    addi x5, x0, 0x5a
    CHECK x5, R(0), 0x5a
    .insn r 0x0b, 0, 0, x1, x2, x3
    TOHOST_FAIL
    addi x6, x0, 0x66
    sw   x6, R(1)(x0)
    TEST_END
