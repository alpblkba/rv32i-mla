#include "isa.h"
// ECALL with rd not x0 is illegal under the contract's strict decode. The contract requires halted and trap high and tohost still 0.
// encoding: 0x000000f3
.section .text
.globl _start
_start:
    addi x5, x0, 0x5a
    CHECK x5, R(0), 0x5a
    .insn i 0x73, 0, x1, x0, 0
    TOHOST_FAIL
    addi x6, x0, 0x66
    sw   x6, R(1)(x0)
    TEST_END
