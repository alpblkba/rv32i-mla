#include "isa.h"
// A right shift immediate with imm[11:5] 0110000 is neither SRLI nor SRAI. The contract requires halted and trap high and tohost still 0.
// encoding: 0x6010d193
.section .text
.globl _start
_start:
    addi x5, x0, 0x5a
    CHECK x5, R(0), 0x5a
    .insn i 0x13, 5, x3, x1, 0x601
    TOHOST_FAIL
    addi x6, x0, 0x66
    sw   x6, R(1)(x0)
    TEST_END
